// SPDX-License-Identifier: GPL-3.0-or-later

#include "portalinhibit.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDebug>
#include <QVariantMap>

#include <utility>

namespace
{
constexpr auto PortalService = "org.freedesktop.portal.Desktop";
constexpr auto PortalPath = "/org/freedesktop/portal/desktop";
constexpr auto InhibitInterface = "org.freedesktop.portal.Inhibit";
constexpr auto RequestInterface = "org.freedesktop.portal.Request";
}

PortalInhibit::PortalInhibit(uint flags, QString reason, QObject *parent)
    : QObject(parent)
    , m_flags(flags)
    , m_reason(std::move(reason))
{
}

PortalInhibit::~PortalInhibit()
{
    if (!m_handle.isEmpty())
        closeRequest(m_handle);
}

void PortalInhibit::setInhibited(QObject *owner, bool inhibited)
{
    if (!owner)
        return;

    if (inhibited) {
        if (m_owners.contains(owner))
            return;

        m_owners.insert(owner);
        connect(owner, &QObject::destroyed, this, [this, owner] {
            m_owners.remove(owner);
            updateRequest();
        });
    } else if (m_owners.remove(owner) == 0) {
        return;
    }

    updateRequest();
}

void PortalInhibit::updateRequest()
{
    if (!m_owners.isEmpty()) {
        if (m_handle.isEmpty() && !m_inhibitPending)
            requestInhibit();
        return;
    }

    if (!m_handle.isEmpty()) {
        const auto handle = std::exchange(m_handle, QString{});
        closeRequest(handle);
    }
}

void PortalInhibit::requestInhibit()
{
    auto call = QDBusMessage::createMethodCall(
        QString::fromLatin1(PortalService), QString::fromLatin1(PortalPath),
        QString::fromLatin1(InhibitInterface), QStringLiteral("Inhibit"));
    call.setArguments({QString{}, m_flags,
                       QVariantMap{{QStringLiteral("reason"), m_reason}}});

    m_inhibitPending = true;
    auto *watcher = new QDBusPendingCallWatcher(
        QDBusConnection::sessionBus().asyncCall(call), this);
    connect(watcher, &QDBusPendingCallWatcher::finished,
            this, &PortalInhibit::inhibitCallFinished);
}

void PortalInhibit::inhibitCallFinished(QDBusPendingCallWatcher *watcher)
{
    const QDBusPendingReply<QDBusObjectPath> reply = *watcher;
    watcher->deleteLater();
    m_inhibitPending = false;

    if (reply.isError()) {
        qWarning() << "Could not acquire portal inhibition:" << reply.error().message();
        return;
    }

    const auto handle = reply.value().path();
    if (handle.isEmpty()) {
        qWarning() << "Portal returned an empty inhibition handle";
        return;
    }

    if (m_owners.isEmpty()) {
        closeRequest(handle);
        return;
    }

    m_handle = handle;
}

void PortalInhibit::closeRequest(const QString &handle)
{
    auto call = QDBusMessage::createMethodCall(
        QString::fromLatin1(PortalService), handle,
        QString::fromLatin1(RequestInterface), QStringLiteral("Close"));
    QDBusConnection::sessionBus().asyncCall(call);
}

