#include "bookmarksmodel.h"

#include "controllers/dbactions.h"

BookMarksModel::BookMarksModel()
{
    this->setList();

    connect(DBActions::getInstance(), &DBActions::bookmarkInserted, [this](UrlData data)
    {
        Q_EMIT this->preItemAppended();
        this->m_list << data.toModel();
        Q_EMIT this->postItemAppended();
    });

    connect(DBActions::getInstance(), &DBActions::iconInserted, [this](QUrl url, QString icon)
    {
        auto index = this->indexOf(FMH::MODEL_KEY::URL, url.toString());
        if (index > -1 && index < this->m_list.size()) {
            this->m_list[index].insert(FMH::MODEL_KEY::ICON, icon);
            Q_EMIT this->updateModel(index, {FMH::MODEL_KEY::ICON});
        }
    });
}

const FMH::MODEL_LIST &BookMarksModel::items() const
{
    return m_list;
}

void BookMarksModel::setList()
{
    this->m_list.clear();
    Q_EMIT this->preListChanged();
    this->m_list << DBActions::getInstance()->getBookmarks();
    Q_EMIT this->postListChanged();
}

void BookMarksModel::insertBookmark(const QUrl &url, const QString &title) const
{
    DBActions::getInstance()->addBookmark({url, title});
}

bool BookMarksModel::isBookmark(const QUrl &url)
{
    return DBActions::getInstance()->isBookmark(url);
}
