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
    // INSERT OR REPLACE updates adddate on revisit so the signal always fires
    // and the model stays current regardless of whether the URL is new or repeat.
    if (this->insert("HISTORY", mData, /*orReplace=*/true))
    {
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
        // Remove the cached icon if this URL no longer appears in history either,
        // to avoid orphaned rows in the ICONS table.
        if (!this->checkExistance("HISTORY", "url", url.toString()))
            this->remove("ICONS", {{FMH::MODEL_KEY::URL, url.toString()}});

        Q_EMIT this->bookmarkRemoved(url);
    }
}

void DBActions::urlIcon(const QUrl &url, const QString &icon)
{
    this->insert("ICONS", {{"url", url.toString()}, {"icon", icon}}, /*orReplace=*/true);
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
    // Only remove icons for URLs that are no longer referenced by bookmarks,
    // so bookmarked-page favicons are preserved across a history clear.
    auto query2 = this->getQuery("DELETE FROM ICONS WHERE url NOT IN (SELECT url FROM BOOKMARKS)");
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

        // Build a column-name → column-index map once per query instead of
        // calling query.record() (which constructs a QSqlRecord) on every key
        // of every row.  For a history of N rows with K model keys this reduces
        // QSqlRecord constructions from N×K to K.
        QVector<QPair<QString, int>> presentCols;
        presentCols.reserve(keys.size());
        {
            const QSqlRecord rec = query.record();
            for (const auto &key : keys) {
                const QString colName = FMH::MODEL_NAME[key];
                const int idx = rec.indexOf(colName);
                if (idx > -1)
                    presentCols.append({colName, idx});
            }
        }

        while (query.next()) {
            QVariantMap data;
            for (const auto &[colName, colIdx] : presentCols)
                data[colName] = query.value(colIdx).toString();

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
