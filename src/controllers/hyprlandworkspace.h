// SPDX-License-Identifier: LGPL-3.0-or-later

#pragma once

#include <QByteArray>
#include <QLocalSocket>
#include <QObject>
#include <QTimer>

class HyprlandWorkspace final : public QObject
{
    Q_OBJECT

public:
    explicit HyprlandWorkspace(QObject *parent = nullptr);

Q_SIGNALS:
    void workspaceChanged();

private:
    void connectEventSocket();
    void scheduleReconnect();
    void readEventData();
    void handleEventLine(const QByteArray &line);

    QLocalSocket m_eventSocket;
    QByteArray m_eventBuffer;
    QTimer m_reconnectTimer;
    QTimer m_workspaceEventTimer;
};
