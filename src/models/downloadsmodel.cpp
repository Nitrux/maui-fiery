#include "downloadsmodel.h"

#include <QMimeDatabase>
#include <QUrl>

#include "controllers/downloadsmanager.h"

DownloadsModel::DownloadsModel(DownloadsManager *parent)
    : QAbstractListModel(parent)
    , m_manager(parent)
{
    connect(m_manager, &DownloadsManager::downloadAdded, this, [this](int index)
    {
        beginInsertRows(QModelIndex(), index, index);
        endInsertRows();
    });

    connect(m_manager, &DownloadsManager::downloadRemoved, this, [this](int index)
    {
        beginRemoveRows(QModelIndex(), index, index);
        endRemoveRows();
    });

    connect(m_manager, &DownloadsManager::downloadChanged, this, [this](int index)
    {
        const QModelIndex modelIndex = this->index(index, 0);
        if (modelIndex.isValid())
            Q_EMIT dataChanged(modelIndex, modelIndex);
    });
}

int DownloadsModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;

    return m_manager->count();
}

QVariant DownloadsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    switch (role)
    {
    case Roles::Name:
        return m_manager->name(index.row());
    case Roles::Url:
        return m_manager->url(index.row());
    case Roles::Directory:
        return m_manager->directory(index.row());
    case Roles::State:
        return m_manager->state(index.row());
    case Roles::Icon:
    {
        static QMimeDatabase mimeDB;
        const QString mimeType = m_manager->mimeType(index.row());
        const QString iconName = mimeType.isEmpty() ? QStringLiteral("folder-download")
                                                    : mimeDB.mimeTypeForName(mimeType).iconName();
        return iconName.isEmpty() ? QStringLiteral("folder-download") : iconName;
    }
    case Roles::FilePath:
        return m_manager->filePath(index.row());
    case Roles::ReceivedBytes:
        return m_manager->receivedBytes(index.row());
    case Roles::TotalBytes:
        return m_manager->totalBytes(index.row());
    case Roles::IsPaused:
        return m_manager->isPaused(index.row());
    default:
        return {};
    }
}

QHash<int, QByteArray> DownloadsModel::roleNames() const
{
    return {
        {Roles::Name, "name"},
        {Roles::Url, "url"},
        {Roles::Directory, "directory"},
        {Roles::State, "state"},
        {Roles::Icon, "icon"},
        {Roles::FilePath, "filePath"},
        {Roles::ReceivedBytes, "receivedBytes"},
        {Roles::TotalBytes, "totalBytes"},
        {Roles::IsPaused, "isPaused"}
    };
}
