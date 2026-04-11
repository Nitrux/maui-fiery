#include "downloadsmanager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSettings>
#include <QUrl>
#include <KNotification>

namespace
{
constexpr auto kDownloadsGroup = "Downloads";
constexpr auto kEntriesKey = "entriesJson";
}

DownloadsManager::DownloadsManager(QObject *parent)
    : QObject(parent)
    , m_model(new DownloadsModel(this))
{
    load();
}

DownloadsManager &DownloadsManager::instance()
{
    static DownloadsManager instance;
    return instance;
}

void DownloadsManager::configurePendingRetry(DownloadItem *download, bool *notifyUser)
{
    if (notifyUser)
        *notifyUser = true;

    if (!download)
        return;

    for (int i = 0; i < m_pendingRetries.count(); ++i)
    {
        const auto pending = m_pendingRetries.at(i);
        if (pending.url != download->url())
            continue;

        if (!pending.downloadDirectory.isEmpty())
            download->setDownloadDirectory(pending.downloadDirectory);

        if (!pending.downloadFileName.isEmpty())
            download->setDownloadFileName(pending.downloadFileName);

        download->setProperty("_fieryReplaceIndex", pending.replaceIndex);
        m_pendingRetries.removeAt(i);

        if (notifyUser)
            *notifyUser = false;
        return;
    }
}

void DownloadsManager::add(DownloadItem *download, bool notifyUser)
{
    if (!download)
        return;

    const QVariant replaceIndexValue = download->property("_fieryReplaceIndex");
    const int replaceIndex = replaceIndexValue.isValid() ? replaceIndexValue.toInt() : -1;

    connectDownload(download);

    if (replaceIndex >= 0 && replaceIndex < m_downloads.count())
    {
        m_downloads[replaceIndex] = recordFromDownload(download);
        save();
        Q_EMIT downloadChanged(replaceIndex);
    }
    else
    {
        const int index = m_downloads.count();
        m_downloads << recordFromDownload(download);
        save();
        Q_EMIT downloadAdded(index);
    }

    if (notifyUser)
        Q_EMIT newDownload(download);
}

void DownloadsManager::remove(int index)
{
    auto *record = recordAt(index);
    if (!record)
        return;

    if (record->request)
        record->request->cancel();

    adjustPendingRetriesAfterRemoval(index);
    m_downloads.removeAt(index);
    save();
    Q_EMIT downloadRemoved(index);
}

void DownloadsManager::removeAndDeleteFile(int index)
{
    auto *record = recordAt(index);
    if (!record)
        return;

    if (record->request && record->request->state() == QWebEngineDownloadRequest::DownloadInProgress)
        record->request->cancel();

    const QString dirPath = QFileInfo(record->downloadDirectory).canonicalFilePath();
    const QString filePath = QFileInfo(record->downloadDirectory
                                       + QDir::separator()
                                       + record->downloadFileName).canonicalFilePath();

    if (dirPath.isEmpty() || filePath.isEmpty() || !filePath.startsWith(dirPath + QDir::separator()))
    {
        qWarning() << "DownloadsManager::removeAndDeleteFile: refusing to delete out-of-bounds path" << filePath;
    }
    else
    {
        QFile::remove(filePath);
    }

    adjustPendingRetriesAfterRemoval(index);
    m_downloads.removeAt(index);
    save();
    Q_EMIT downloadRemoved(index);
}

void DownloadsManager::clearFinished()
{
    for (int index = m_downloads.count() - 1; index >= 0; --index)
    {
        const auto *record = recordAt(index);
        if (!record)
            continue;

        switch (record->state)
        {
        case QWebEngineDownloadRequest::DownloadCompleted:
        case QWebEngineDownloadRequest::DownloadCancelled:
        case QWebEngineDownloadRequest::DownloadInterrupted:
            adjustPendingRetriesAfterRemoval(index);
            m_downloads.removeAt(index);
            Q_EMIT downloadRemoved(index);
            break;
        default:
            break;
        }
    }

    save();
}

void DownloadsManager::pause(int index)
{
    auto *record = recordAt(index);
    if (!record || !record->request)
        return;

    record->request->pause();
}

void DownloadsManager::resume(int index)
{
    auto *record = recordAt(index);
    if (!record)
        return;

    if (record->request)
    {
        record->request->resume();
        return;
    }

    if (!record->url.isValid())
        return;

    for (int i = m_pendingRetries.count() - 1; i >= 0; --i)
    {
        if (m_pendingRetries.at(i).replaceIndex == index)
            m_pendingRetries.removeAt(i);
    }

    PendingRetry pending;
    pending.url = record->url;
    pending.downloadDirectory = record->downloadDirectory;
    pending.downloadFileName = record->downloadFileName;
    pending.replaceIndex = index;
    m_pendingRetries << pending;

    Q_EMIT retryRequested(record->url);
}

void DownloadsManager::cancelDownload(DownloadItem *download)
{
    const int index = indexOf(download);
    if (index >= 0)
        removeAndDeleteFile(index);
}

DownloadItem *DownloadsManager::item(int index)
{
    auto *record = recordAt(index);
    return record ? record->request.data() : nullptr;
}

int DownloadsManager::count() const
{
    return m_downloads.count();
}

QString DownloadsManager::name(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->downloadFileName : QString();
}

QUrl DownloadsManager::url(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->url : QUrl();
}

QString DownloadsManager::directory(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->downloadDirectory : QString();
}

int DownloadsManager::state(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->state : static_cast<int>(QWebEngineDownloadRequest::DownloadRequested);
}

QString DownloadsManager::mimeType(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->mimeType : QString();
}

qint64 DownloadsManager::totalBytes(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->totalBytes : 0;
}

qint64 DownloadsManager::receivedBytes(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->receivedBytes : 0;
}

bool DownloadsManager::isPaused(int index) const
{
    const auto *record = recordAt(index);
    return record ? record->paused : false;
}

QUrl DownloadsManager::filePath(int index) const
{
    const auto *record = recordAt(index);
    if (!record)
        return {};

    const QString dirCanon = QFileInfo(record->downloadDirectory).canonicalFilePath();
    const QString fullPath = record->downloadDirectory + QDir::separator() + record->downloadFileName;
    const QString fileCanon = QFileInfo(fullPath).canonicalFilePath();
    if (dirCanon.isEmpty() || fileCanon.isEmpty() || !fileCanon.startsWith(dirCanon + QDir::separator()))
        return {};

    return QUrl::fromLocalFile(fileCanon);
}

void DownloadsManager::notifyComplete(const QString &name)
{
    static const QRegularExpression controlChars(QStringLiteral("[\\x00-\\x1F\\x7F]"));
    const QString safeName = name.left(200).remove(controlChars);

    KNotification *n = new KNotification(QStringLiteral("downloadComplete"), KNotification::CloseOnTimeout);
    n->setTitle(QStringLiteral("Download Finished"));
    n->setText(safeName);
    n->setIconName(QStringLiteral("folder-download"));
    n->sendEvent();
}

DownloadsManager::~DownloadsManager() = default;

DownloadsModel *DownloadsManager::model() const
{
    return m_model;
}

int DownloadsManager::indexOf(DownloadItem *download) const
{
    for (int index = 0; index < m_downloads.count(); ++index)
    {
        if (m_downloads.at(index).request == download)
            return index;
    }

    return -1;
}

const DownloadsManager::DownloadRecord *DownloadsManager::recordAt(int index) const
{
    if (index < 0 || index >= m_downloads.count())
        return nullptr;

    return &m_downloads.at(index);
}

DownloadsManager::DownloadRecord *DownloadsManager::recordAt(int index)
{
    if (index < 0 || index >= m_downloads.count())
        return nullptr;

    return &m_downloads[index];
}

DownloadsManager::DownloadRecord DownloadsManager::recordFromDownload(DownloadItem *download) const
{
    DownloadRecord record;
    if (!download)
        return record;

    record.request = download;
    record.url = download->url();
    record.downloadDirectory = download->downloadDirectory();
    record.downloadFileName = download->downloadFileName();
    record.mimeType = download->mimeType();
    record.state = download->state();
    record.totalBytes = download->totalBytes();
    record.receivedBytes = download->receivedBytes();
    record.paused = download->isPaused();
    return record;
}

void DownloadsManager::connectDownload(DownloadItem *download)
{
    auto notifier = [this, download]() { emitDownloadChanged(download); };
    auto persistingNotifier = [this, download]()
    {
        emitDownloadChanged(download);
        save();
    };

    connect(download, &DownloadItem::stateChanged, this, persistingNotifier);
    connect(download, &DownloadItem::receivedBytesChanged, this, notifier);
    connect(download, &DownloadItem::totalBytesChanged, this, notifier);
    connect(download, &DownloadItem::isPausedChanged, this, persistingNotifier);
    connect(download, &DownloadItem::downloadDirectoryChanged, this, persistingNotifier);
    connect(download, &DownloadItem::downloadFileNameChanged, this, persistingNotifier);
    connect(download, &QObject::destroyed, this, [this, download]() {
        const int index = indexOf(download);
        if (index < 0)
            return;

        m_downloads[index].request = nullptr;
        save();
        Q_EMIT downloadChanged(index);
    });
}

void DownloadsManager::updateRecord(int index)
{
    auto *record = recordAt(index);
    if (!record || !record->request)
        return;

    *record = recordFromDownload(record->request);
}

void DownloadsManager::emitDownloadChanged(DownloadItem *download)
{
    const int index = indexOf(download);
    if (index < 0)
        return;

    updateRecord(index);
    Q_EMIT downloadChanged(index);
}

void DownloadsManager::load()
{
    QSettings settings(QStringLiteral("Maui"), QStringLiteral("fiery"));
    settings.beginGroup(QLatin1StringView(kDownloadsGroup));
    const QString entriesJson = settings.value(QLatin1StringView(kEntriesKey)).toString();
    settings.endGroup();

    const QJsonDocument doc = QJsonDocument::fromJson(entriesJson.toUtf8());
    if (!doc.isArray())
        return;

    const auto entries = doc.array();
    for (const auto &entry : entries)
    {
        if (!entry.isObject())
            continue;

        const auto object = entry.toObject();
        DownloadRecord record;
        record.url = QUrl(object.value(QStringLiteral("url")).toString());
        record.downloadDirectory = object.value(QStringLiteral("downloadDirectory")).toString();
        record.downloadFileName = object.value(QStringLiteral("downloadFileName")).toString();
        record.mimeType = object.value(QStringLiteral("mimeType")).toString();
        record.state = static_cast<DownloadItem::DownloadState>(object.value(QStringLiteral("state")).toInt(static_cast<int>(DownloadItem::DownloadRequested)));
        record.receivedBytes = object.value(QStringLiteral("receivedBytes")).toString().toLongLong();
        record.totalBytes = object.value(QStringLiteral("totalBytes")).toString().toLongLong();
        record.paused = object.value(QStringLiteral("paused")).toBool(false);

        if (record.downloadFileName.isEmpty() && record.url.isValid())
            record.downloadFileName = QFileInfo(record.url.path()).fileName();

        if (record.state == DownloadItem::DownloadInProgress || record.paused)
        {
            record.state = DownloadItem::DownloadInterrupted;
            record.paused = false;
        }

        if (!record.url.isValid() && record.downloadFileName.isEmpty())
            continue;

        m_downloads << record;
    }
}

void DownloadsManager::save() const
{
    QJsonArray entries;
    for (const auto &record : m_downloads)
    {
        QJsonObject object;
        object.insert(QStringLiteral("url"), record.url.toString());
        object.insert(QStringLiteral("downloadDirectory"), record.downloadDirectory);
        object.insert(QStringLiteral("downloadFileName"), record.downloadFileName);
        object.insert(QStringLiteral("mimeType"), record.mimeType);
        object.insert(QStringLiteral("state"), static_cast<int>(record.state));
        object.insert(QStringLiteral("receivedBytes"), QString::number(record.receivedBytes));
        object.insert(QStringLiteral("totalBytes"), QString::number(record.totalBytes));
        object.insert(QStringLiteral("paused"), record.paused);
        entries.append(object);
    }

    QSettings settings(QStringLiteral("Maui"), QStringLiteral("fiery"));
    settings.beginGroup(QLatin1StringView(kDownloadsGroup));
    settings.setValue(QLatin1StringView(kEntriesKey), QString::fromUtf8(QJsonDocument(entries).toJson(QJsonDocument::Compact)));
    settings.endGroup();
}

void DownloadsManager::adjustPendingRetriesAfterRemoval(int index)
{
    for (int i = m_pendingRetries.count() - 1; i >= 0; --i)
    {
        if (m_pendingRetries.at(i).replaceIndex == index)
        {
            m_pendingRetries.removeAt(i);
        }
        else if (m_pendingRetries.at(i).replaceIndex > index)
        {
            --m_pendingRetries[i].replaceIndex;
        }
    }
}
