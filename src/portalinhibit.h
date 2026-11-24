// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QSet>
#include <QString>

class QDBusPendingCallWatcher;

class PortalInhibit final : public QObject
{
    Q_OBJECT

public:
    PortalInhibit(uint flags, QString reason, QObject *parent = nullptr);
    ~PortalInhibit() override;

    Q_INVOKABLE void setInhibited(QObject *owner, bool inhibited);

private:
    void updateRequest();
    void requestInhibit();
    void inhibitCallFinished(QDBusPendingCallWatcher *watcher);
    void closeRequest(const QString &handle);

    QSet<QObject *> m_owners;
    uint m_flags;
    QString m_reason;
    QString m_handle;
    bool m_inhibitPending{false};
};
