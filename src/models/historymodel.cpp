#include "historymodel.h"

#include "controllers/dbactions.h"

HistoryModel::HistoryModel()
{
    this->setList();

    connect(DBActions::getInstance(), &DBActions::historyUrlInserted, [this](UrlData data)
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

const FMH::MODEL_LIST &HistoryModel::items() const
{
    return m_list;
}

void HistoryModel::appendUrl(const QUrl &url, const QString &title)
{
    DBActions::getInstance()->addToHistory({url, title});
}

void HistoryModel::updateIcon(const QUrl &url, const QString &icon)
{
    DBActions::getInstance()->urlIcon(url, icon);
}

void HistoryModel::clearAll()
{
    DBActions::getInstance()->clearHistory();
    setList();
}

void HistoryModel::setList()
{
    this->m_list.clear();
    Q_EMIT this->preListChanged();
    this->m_list << DBActions::getInstance()->getHistory();
    Q_EMIT this->postListChanged();
}
