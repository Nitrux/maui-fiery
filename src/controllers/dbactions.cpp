#include "dbactions.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlError>

DBActions *DBActions::m_instance = nullptr;

void DBActions::addToHistory(const UrlData &data)
{
    auto mData = data.toMap();
    mData.insert("adddate", QDateTime::currentDateTime().toString(Qt::ISODate));
    qInfo() << "addToHistory:" << data.url << "insert result:";
    // INSERT OR REPLACE updates adddate on revisit so the signal always fires
    // and the model stays current regardless of whether the URL is new or repeat.
    if (this->insert("HISTORY", mData, /*orReplace=*/true))
    {
        qInfo() << "  -> insert OK, emitting historyUrlInserted";
        Q_EMIT this->historyUrlInserted(data);
    }
}

void DBActions::addBookmark(const UrlData &data)
{
    auto mData = data.toMap();
    mData.insert("adddate", QDateTime::currentDateTime().toString(Qt::ISODate));
    if (this->insert("BOOKMARKS", mData))
    {
        Q_EMIT this->bookmarkInserted(data);
    }
}

void DBActions::removeBookmark(const QUrl &url)
{
    if (this->remove("BOOKMARKS", {{FMH::MODEL_KEY::URL, url.toString()}}))
    {
        Q_EMIT this->bookmarkRemoved(url);
    }
}

void DBActions::urlIcon(const QUrl &url, const QString &icon)
{
    if(!this->insert("ICONS", {{"url", url.toString()}, {"icon", icon}}))
    {
        this->update("ICONS", {{FMH::MODEL_KEY::ICON, icon}}, {{"url", url}});
    }

    Q_EMIT this->iconInserted(url, icon);
}

FMH::MODEL_LIST DBActions::getHistory() const
{
return FMH::toModelList(this->get("select * from HISTORY h left join ICONS i on i.url = h.url"));
}

FMH::MODEL_LIST DBActions::getBookmarks() const
{
    return FMH::toModelList(this->get("select * from BOOKMARKS b left join ICONS i on i.url = b.url"));
}

bool DBActions::isBookmark(const QUrl &url)
{
    return checkExistance("BOOKMARKS", "url", url.toString());
}

void DBActions::clearHistory()
{
    auto query = this->getQuery("DELETE FROM HISTORY");
    query.exec();
    auto query2 = this->getQuery("DELETE FROM ICONS");
    query2.exec();
    Q_EMIT this->historyCleared();
}

DBActions::DBActions(QObject *parent) : DB(parent)
{
    connect(qApp, &QCoreApplication::aboutToQuit, []()
    {
        delete m_instance;
        m_instance = nullptr;
    });
}

const QVariantList DBActions::get(const QString &queryTxt, std::function<bool(QVariantMap &item)> modifier) const
{
    QVariantList mapList;

    auto query = this->getQuery(queryTxt);

    if (query.exec()) {
        const auto keys = FMH::MODEL_NAME.keys();

        while (query.next()) {
            QVariantMap data;
            for (const auto &key : keys) {

                if (query.record().indexOf(FMH::MODEL_NAME[key]) > -1) {
                    data[FMH::MODEL_NAME[key]] = query.value(FMH::MODEL_NAME[key]).toString();
                }
            }

            if (modifier) {
                if (!modifier(data))
                {
                    continue;
                }
            }

            mapList << data;
        }

    } else
    {
        qWarning() << "DBActions query failed:" << query.lastError() << query.lastQuery();
    }

    return mapList;
}
