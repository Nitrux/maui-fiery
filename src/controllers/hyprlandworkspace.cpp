// SPDX-License-Identifier: LGPL-3.0-or-later

#include "hyprlandworkspace.h"

#include <QDir>

namespace
{
constexpr qsizetype kMaximumEventBufferSize = 256 * 1024;
constexpr qsizetype kMaximumEventLineSize = 64 * 1024;

QString eventSocketPath()
{
    const QString signature = QString::fromLocal8Bit(qgetenv("HYPRLAND_INSTANCE_SIGNATURE")).trimmed();
    if (signature.isEmpty())
        return {};

    QString runtimeDirectory = QString::fromLocal8Bit(qgetenv("XDG_RUNTIME_DIR")).trimmed();
    if (runtimeDirectory.isEmpty())
        runtimeDirectory = QStringLiteral("/tmp");

    return QDir(runtimeDirectory).filePath(QStringLiteral("hypr/%1/.socket2.sock").arg(signature));
}
}

HyprlandWorkspace::HyprlandWorkspace(QObject *parent)
    : QObject(parent)
{
    m_reconnectTimer.setSingleShot(true);
    m_reconnectTimer.setInterval(2000);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &HyprlandWorkspace::connectEventSocket);

    m_workspaceEventTimer.setSingleShot(true);
    m_workspaceEventTimer.setInterval(40);
    connect(&m_workspaceEventTimer, &QTimer::timeout, this, &HyprlandWorkspace::workspaceChanged);

    connect(&m_eventSocket, &QLocalSocket::readyRead, this, &HyprlandWorkspace::readEventData);
    connect(&m_eventSocket, &QLocalSocket::disconnected, this, [this]() {
        m_eventBuffer.clear();
        scheduleReconnect();
    });
    connect(&m_eventSocket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        scheduleReconnect();
    });

    QTimer::singleShot(0, this, &HyprlandWorkspace::connectEventSocket);
}

void HyprlandWorkspace::connectEventSocket()
{
    const QString socketPath = eventSocketPath();
    if (socketPath.isEmpty())
        return;

    if (m_eventSocket.state() == QLocalSocket::ConnectedState
        || m_eventSocket.state() == QLocalSocket::ConnectingState)
    {
        return;
    }

    m_eventBuffer.clear();
    m_eventSocket.abort();
    m_eventSocket.connectToServer(socketPath, QIODevice::ReadOnly);
}

void HyprlandWorkspace::scheduleReconnect()
{
    if (!m_reconnectTimer.isActive())
        m_reconnectTimer.start();
}

void HyprlandWorkspace::readEventData()
{
    const qint64 remainingCapacity = kMaximumEventBufferSize - m_eventBuffer.size();
    m_eventBuffer += m_eventSocket.read(remainingCapacity + 1);

    if (m_eventBuffer.size() > kMaximumEventBufferSize
        || (m_eventBuffer.indexOf('\n') < 0 && m_eventBuffer.size() > kMaximumEventLineSize))
    {
        m_eventBuffer.clear();
        m_eventSocket.abort();
        scheduleReconnect();
        return;
    }

    qsizetype newlineIndex = m_eventBuffer.indexOf('\n');
    while (newlineIndex >= 0)
    {
        if (newlineIndex > kMaximumEventLineSize)
        {
            m_eventBuffer.clear();
            m_eventSocket.abort();
            scheduleReconnect();
            return;
        }

        const QByteArray line = m_eventBuffer.left(newlineIndex).trimmed();
        m_eventBuffer.remove(0, newlineIndex + 1);
        if (!line.isEmpty())
            handleEventLine(line);

        newlineIndex = m_eventBuffer.indexOf('\n');
    }
}

void HyprlandWorkspace::handleEventLine(const QByteArray &line)
{
    const qsizetype separatorIndex = line.indexOf(" >> ");
    const qsizetype compactSeparatorIndex = separatorIndex >= 0 ? separatorIndex : line.indexOf(">>");
    if (compactSeparatorIndex <= 0)
        return;

    const QByteArray eventName = line.left(compactSeparatorIndex).trimmed();
    if (eventName == QByteArrayLiteral("workspace")
        || eventName == QByteArrayLiteral("workspacev2"))
    {
        m_workspaceEventTimer.start();
    }
}
