#include "downloadsmodel.h"

#include <QUrl>
#include <QDebug>
#include "controllers/downloadsmanager.h"
#include <QMimeDatabase>
#include <QDir>

#include <QWebEngineDownloadRequest>

DownloadsModel::DownloadsModel(DownloadsManager *parent) : QAbstractListModel(parent)
    ,m_manager(parent)
{

    connect(m_manager, &DownloadsManager::newDownload, [this](DownloadItem *)
            {
                beginResetModel();
                endResetModel();
            });

    connect(m_manager, &DownloadsManager::downloadRemoved, [this](int index)
            {
                beginRemoveRows(QModelIndex(), index, index);
                endRemoveRows();
            });
}

int DownloadsModel::rowCount(const QModelIndex &parent) const
{
    if(parent.isValid())
    {
        return 0;
    }

    return m_manager->count();
}

QVariant DownloadsModel::data(const QModelIndex &index, int role) const
{
    if(!index.isValid())
    {
        return QVariant();
    }

    auto item = m_manager->item(index.row());
    switch (role)
    {
    case Roles::Name: return QVariant(item->downloadFileName());
    case Roles::Url: return QVariant(item->url());
    case Roles::Directory: return QVariant(item->downloadDirectory());
    case Roles::State: return QVariant(item->state());
    case Roles::Icon:
    {
        static auto mimeDB = QMimeDatabase();
        return mimeDB.mimeTypeForName(item->mimeType()).iconName();
    }
    case Roles::Download:
    {
        return QVariant::fromValue(m_manager->item(index.row()));
    }
    case Roles::FilePath:
    {
        const QString dirCanon  = QFileInfo(item->downloadDirectory()).canonicalFilePath();
        const QString fullPath  = item->downloadDirectory() + QDir::separator() + item->downloadFileName();
        const QString fileCanon = QFileInfo(fullPath).canonicalFilePath();
        if (dirCanon.isEmpty() || fileCanon.isEmpty() || !fileCanon.startsWith(dirCanon + QDir::separator()))
            return QVariant();
        return QUrl::fromLocalFile(fileCanon);
    }
    default: return QVariant();
    }
}

QHash<int, QByteArray> DownloadsModel::roleNames() const
{
    return {{Roles::Name, "name"}, {Roles::Url, "url"}, {Roles::Directory, "directory"}, {Roles::State, "state"}, {Roles::Icon, "icon"}, {Roles::Download, "download"}, {Roles::FilePath, "filePath"}};
}
