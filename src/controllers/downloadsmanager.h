#pragma once

#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QVector>

#include "models/downloadsmodel.h"
#include <QWebEngineDownloadRequest>

using DownloadItem = QWebEngineDownloadRequest;

class DownloadsManager : public QObject
{
//    Q_DISABLE_COPY_MOVE(DownloadsManager)
    Q_OBJECT

    Q_PROPERTY(DownloadsModel* model READ model CONSTANT FINAL)

public:
    enum State {
        DownloadRequested,
        DownloadInProgress,
        DownloadCompleted,
        DownloadCancelled,
        DownloadInterrupted,
    }; Q_ENUM(State)

    struct DownloadRecord
    {
        QPointer<DownloadItem> request;
        QUrl url;
        QString downloadDirectory;
        QString downloadFileName;
        QString mimeType;
        DownloadItem::DownloadState state = DownloadItem::DownloadRequested;
        qint64 totalBytes = 0;
        qint64 receivedBytes = 0;
        bool paused = false;
    };

    DownloadsModel *model() const;
    static DownloadsManager &instance();

    void configurePendingRetry(DownloadItem *download, bool *notifyUser);

public Q_SLOTS:
    void add(DownloadItem *download, bool notifyUser = true);
    void remove(int index);
    void removeAndDeleteFile(int index);
    void clearFinished();
    void pause(int index);
    void resume(int index);
    void cancelDownload(DownloadItem *download);
    void notifyComplete(const QString &name);

    DownloadItem *item(int index);
    int count() const;

    QString name(int index) const;
    QUrl url(int index) const;
    QString directory(int index) const;
    int state(int index) const;
    QString mimeType(int index) const;
    qint64 totalBytes(int index) const;
    qint64 receivedBytes(int index) const;
    bool isPaused(int index) const;
    QUrl filePath(int index) const;

private:
    struct PendingRetry
    {
        QUrl url;
        QString downloadDirectory;
        QString downloadFileName;
        int replaceIndex = -1;
    };

    DownloadsModel *m_model;
    QVector<DownloadRecord> m_downloads;
    QVector<PendingRetry> m_pendingRetries;

    explicit DownloadsManager(QObject *parent = nullptr);
    ~DownloadsManager();

    int indexOf(DownloadItem *download) const;
    const DownloadRecord *recordAt(int index) const;
    DownloadRecord *recordAt(int index);
    DownloadRecord recordFromDownload(DownloadItem *download) const;
    void connectDownload(DownloadItem *download);
    void updateRecord(int index);
    void emitDownloadChanged(DownloadItem *download);
    void load();
    void save() const;
    void adjustPendingRetriesAfterRemoval(int index);

Q_SIGNALS:
    void newDownload(DownloadItem *download);
    void downloadAdded(int index);
    void downloadRemoved(int index);
    void downloadChanged(int index);
    void retryRequested(const QUrl &url);
};
