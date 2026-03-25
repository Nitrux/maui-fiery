#include "dbactions.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlError>

DBActions *DBActions::m_instance = nullptr;

void DBActions::addToHistory(const UrlData &data)
{
    const QString now    = QDateTime::currentDateTime().toString(Qt::ISODate);
    const QString urlStr = data.url.toString();

    const bool ok = this->runQuery(
        QStringLiteral(
            "INSERT INTO HISTORY_URLS(url, title, visit_count, last_visit) VALUES(?,?,1,?) "
            "ON CONFLICT(url) DO UPDATE SET "
            "  title=excluded.title,"
            "  visit_count=visit_count+1,"
            "  last_visit=excluded.last_visit"),
        {urlStr, data.title, now});

    if (ok) {
        this->runQuery(
            QStringLiteral("INSERT INTO HISTORY_VISITS(url, visit_time) VALUES(?,?)"),
            {urlStr, now});
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
        if (!this->checkExistance("HISTORY_URLS", "url", url.toString()))
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
    // last_visit aliased to adddate so the existing QML model roles keep working.
    return FMH::toModelList(this->get(
        QStringLiteral(
            "SELECT u.url, u.title, u.last_visit AS adddate, u.visit_count, i.icon "
            "FROM HISTORY_URLS u LEFT JOIN ICONS i ON i.url = u.url "
            "ORDER BY u.last_visit DESC")));
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
    this->runQuery(QStringLiteral("DELETE FROM HISTORY_VISITS"));
    this->runQuery(QStringLiteral("DELETE FROM HISTORY_URLS"));
    this->runQuery(QStringLiteral(
        "DELETE FROM ICONS WHERE url NOT IN (SELECT url FROM BOOKMARKS)"));
    Q_EMIT this->historyCleared();
}

void DBActions::pushClosedTab(const QStringList &urls)
{
    if (urls.isEmpty())
        return;
    const QString now = QDateTime::currentDateTime().toString(Qt::ISODate);
    this->runQuery(
        QStringLiteral("INSERT INTO RECENTLY_CLOSED(urls, closeddate) VALUES(?,?)"),
        {urls.join(QLatin1Char('\n')), now});
    this->runQuery(QStringLiteral(
        "DELETE FROM RECENTLY_CLOSED WHERE id NOT IN "
        "(SELECT id FROM RECENTLY_CLOSED ORDER BY id DESC LIMIT 50)"));
    Q_EMIT this->closedTabsChanged();
}

QStringList DBActions::popClosedTab()
{
    auto q = this->getQuery(
        QStringLiteral("SELECT id, urls FROM RECENTLY_CLOSED ORDER BY id DESC LIMIT 1"));
    if (!q.exec() || !q.next())
        return {};
    const int id          = q.value(0).toInt();
    const QStringList urls = q.value(1).toString().split(
        QLatin1Char('\n'), Qt::SkipEmptyParts);
    this->runQuery(
        QStringLiteral("DELETE FROM RECENTLY_CLOSED WHERE id=?"), {id});
    Q_EMIT this->closedTabsChanged();
    return urls;
}

bool DBActions::hasClosedTabs() const
{
    return this->checkExistance(
        QStringLiteral("SELECT 1 FROM RECENTLY_CLOSED LIMIT 1"));
}

void DBActions::clearClosedTabs()
{
    this->runQuery(QStringLiteral("DELETE FROM RECENTLY_CLOSED"));
    Q_EMIT this->closedTabsChanged();
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
