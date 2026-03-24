#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QString>

class WidevineInstaller : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State   state    READ state    NOTIFY stateChanged)
    Q_PROPERTY(int     progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(bool    isInstalled   READ isInstalled   NOTIFY stateChanged)

public:
    enum class State { Idle, Downloading, Extracting, Ready, Failed };
    Q_ENUM(State)

    static WidevineInstaller &instance();

    State   state()         const { return m_state; }
    int     progress()      const { return m_progress; }
    QString statusMessage() const { return m_statusMessage; }

    bool isInstalled() const;
    Q_INVOKABLE QString installedPath() const;
    Q_INVOKABLE void install();
    Q_INVOKABLE void cancel();

Q_SIGNALS:
    void stateChanged();
    void progressChanged();
    void statusMessageChanged();
    void installed();

private:
    explicit WidevineInstaller(QObject *parent = nullptr);
    ~WidevineInstaller() override = default;

    void setState(State s);
    void setProgress(int p);
    void setStatusMessage(const QString &msg);
    void fail(const QString &reason);
    void cleanup();

    // Pipeline stages
    void startDownload();
    void onDownloadProgress(qint64 received, qint64 total);
    void onDownloadFinished();
    void extractTar(const QString &tarPath);
    void onExtractionFinished(int exitCode, QProcess::ExitStatus status);

    QNetworkAccessManager  m_nam;
    QNetworkReply         *m_reply   = nullptr;
    QProcess              *m_process = nullptr;
    QByteArray             m_buffer;

    State   m_state    = State::Idle;
    int     m_progress = 0;
    QString m_statusMessage;

    QString m_cdmDir;
    QString m_destPath;
    QString m_manifestPath;
    QString m_tempTarPath;
};
