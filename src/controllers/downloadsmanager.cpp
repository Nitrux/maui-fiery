#include "downloadsmanager.h"
#include <QUrl>
#include <QFile>
#include <QDir>
#include <KNotification>

DownloadsManager::DownloadsManager(QObject *parent) : QObject(parent)
    ,m_model(new DownloadsModel(this))
{

}

DownloadsManager &DownloadsManager::instance()
{
    static DownloadsManager instance;
    return instance;
}

void DownloadsManager::add(DownloadItem *download)
{
    m_downloads << download;
    Q_EMIT newDownload(download);
}

void DownloadsManager::remove(int index)
{
    if(index < 0 || index >= m_downloads.count())
        return;

    m_downloads.at(index)->cancel();
    m_downloads.erase(m_downloads.begin() + index);
    Q_EMIT downloadRemoved(index);
}

void DownloadsManager::removeAndDeleteFile(int index)
{
    if(index < 0 || index >= m_downloads.count())
        return;

    auto item = m_downloads.at(index);

    if(item->state() == QWebEngineDownloadRequest::DownloadInProgress)
        item->cancel();

    // Resolve both the download directory and the candidate file path to their
    // canonical (symlink-resolved, dot-segment-collapsed) absolute forms before
    // deleting, so that a server-injected traversal sequence (e.g. "../../.bashrc")
    // in the filename cannot escape the intended download directory.
    const QString dirPath  = QFileInfo(item->downloadDirectory()).canonicalFilePath();
    const QString filePath = QFileInfo(item->downloadDirectory()
                                       + QDir::separator()
                                       + item->downloadFileName()).canonicalFilePath();

    if (dirPath.isEmpty() || filePath.isEmpty() || !filePath.startsWith(dirPath + QDir::separator()))
    {
        qWarning() << "DownloadsManager::removeAndDeleteFile: refusing to delete out-of-bounds path" << filePath;
    }
    else
    {
        QFile::remove(filePath);
    }

    m_downloads.erase(m_downloads.begin() + index);
    Q_EMIT downloadRemoved(index);
}

void DownloadsManager::cancelDownload(DownloadItem *download)
{
    int index = m_downloads.indexOf(download);
    if (index >= 0)
        removeAndDeleteFile(index);
}

DownloadItem *DownloadsManager::item(int index)
{
    if(index < 0 || index >= m_downloads.count())
        return nullptr;

    return m_downloads.at(index);
}

int DownloadsManager::count() const
{
    return m_downloads.count();
}

void DownloadsManager::notifyComplete(const QString &name)
{
    KNotification *n = new KNotification(QStringLiteral("downloadComplete"), KNotification::CloseOnTimeout);
    n->setTitle(QStringLiteral("Download Finished"));
    n->setText(name);
    n->setIconName(QStringLiteral("folder-download"));
    n->sendEvent();
}

DownloadsManager::~DownloadsManager()
{
//    qDeleteAll(m_downloads);
}

DownloadsModel *DownloadsManager::model() const
{
    return m_model;
}
