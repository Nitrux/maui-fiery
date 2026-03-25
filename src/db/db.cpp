/*
 *   Copyright 2018 Camilo Higuita <milo.h@aol.com>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library General Public License as
 *   published by the Free Software Foundation; either version 2, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details
 *
 *   You should have received a copy of the GNU Library General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include "db.h"

#include <QDebug>
#include <QDir>
#include <QList>
#include <QSqlDriver>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QRegularExpression>
#include <QUuid>

#include <MauiKit4/FileBrowsing/fmstatic.h>

const static QString DB_Dir_Path = FMStatic::DataPath + "/fiery";
const static QString DB_Path = DB_Dir_Path + "/data.db";

DB::DB(QObject *parent) : QObject(parent)
{
    QDir collectionDBPath_dir(DB_Dir_Path);
    if (!collectionDBPath_dir.exists())
        collectionDBPath_dir.mkpath(".");

    this->name = QUuid::createUuid().toString();
    if (!FMH::fileExists(QUrl::fromLocalFile(DB_Path))) {
        this->openDB(this->name);
        qInfo() << "Database not found, creating it at" << DB_Path;
        this->prepareCollectionDB();
    } else
        this->openDB(this->name);
}

DB::~DB()
{
    this->m_db.close();
}

void DB::openDB(const QString &name)
{
    if (!QSqlDatabase::contains(name)) {
        this->m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), name);
        this->m_db.setDatabaseName(DB_Path);
    }

    if (!this->m_db.isOpen()) {
        if (!this->m_db.open())
            qCritical() << "Failed to open database:" << this->m_db.lastError().text() << m_db.connectionName();
    }
    auto walQuery = this->getQuery("PRAGMA journal_mode=WAL");
    walQuery.exec();
    auto query = this->getQuery("PRAGMA synchronous=NORMAL");
    query.exec();

    auto fkQuery = this->getQuery("PRAGMA foreign_keys=ON");
    fkQuery.exec();

    migrateSchema();
}

void DB::prepareCollectionDB() const
{
    QSqlQuery query(this->m_db);

    QFile file(":/db/script.sql");

    if (!file.exists()) {
        qCritical() << "Database schema resource not found:" << file.fileName();
        return;
    }

    if (!file.open(QIODevice::ReadOnly)) {
        qCritical() << "Failed to open database schema resource:" << file.fileName();
        return;
    }

    bool hasText;
    QString line;
    QByteArray readLine;
    QString cleanedLine;
    QStringList strings;

    while (!file.atEnd()) {
        hasText = false;
        line = "";
        readLine = "";
        cleanedLine = "";
        strings.clear();
        while (!hasText) {
            readLine = file.readLine();
            cleanedLine = readLine.trimmed();
            strings = cleanedLine.split("--");
            cleanedLine = strings.at(0);
            if (!cleanedLine.startsWith("--") && !cleanedLine.startsWith("DROP") && !cleanedLine.isEmpty())
                line += cleanedLine;
            if (cleanedLine.endsWith(";"))
                break;
            if (cleanedLine.startsWith("COMMIT"))
                hasText = true;
        }
        if (!line.isEmpty()) {
            if (!query.exec(line)) {
                qWarning() << "Schema statement failed:" << query.lastQuery() << query.lastError();
            }

        }
    }
    file.close();
}

static bool isValidIdentifier(const QString &name)
{
    static const QRegularExpression re(QStringLiteral("^[A-Za-z_][A-Za-z0-9_]*$"));
    return re.match(name).hasMatch();
}

bool DB::checkExistance(const QString &tableName, const QString &searchId, const QString &search) const
{
    if (!isValidIdentifier(tableName) || !isValidIdentifier(searchId)) {
        qWarning() << "DB::checkExistance: invalid identifier(s):" << tableName << searchId;
        return false;
    }
    const QString queryStr = QString("SELECT %1 FROM %2 WHERE %3 = ?").arg(searchId, tableName, searchId);
    QSqlQuery query(this->m_db);
    query.prepare(queryStr);
    query.addBindValue(search);
    if (query.exec())
        return query.next();
    qWarning() << "DB::checkExistance failed:" << query.lastError().text();
    return false;
}

bool DB::checkExistance(const QString &queryStr) const
{
    auto query = this->getQuery(queryStr);

    if (query.exec()) {
        if (query.next())
            return true;
    } else
        qWarning() << "DB::checkExistance failed:" << query.lastError().text();

    return false;
}

QSqlQuery DB::getQuery(const QString &queryTxt) const
{
    QSqlQuery query(queryTxt, this->m_db);
    return query;
}

bool DB::insert(const QString &tableName, const QVariantMap &insertData, bool orReplace)
{
    if (tableName.isEmpty()) {
        qWarning() << "DB::insert: table name is empty";
        return false;

    } else if (insertData.isEmpty()) {
        qWarning() << "DB::insert: insert data is empty";
        return false;
    }

    if (!isValidIdentifier(tableName)) {
        qWarning() << "DB::insert: invalid table name:" << tableName;
        return false;
    }

    QStringList strValues;
    QStringList fields = insertData.keys();
    QVariantList values = insertData.values();
    int totalFields = fields.size();
    for (const QString &field : std::as_const(fields)) {
        if (!isValidIdentifier(field)) {
            qWarning() << "DB::insert: invalid column name:" << field;
            return false;
        }
    }
    for (int i = 0; i < totalFields; ++i)
        strValues.append("?");

    const QString verb = orReplace ? QStringLiteral("INSERT OR REPLACE INTO") : QStringLiteral("INSERT INTO");
    QString sqlQueryString = verb + " " + tableName + " (" + QString(fields.join(",")) + ") VALUES(" + QString(strValues.join(",")) + ")";
    QSqlQuery query(this->m_db);
    query.prepare(sqlQueryString);

    int k = 0;
    for (const QVariant &value : values)
        query.bindValue(k++, value);

    if (!query.exec()) {
        qWarning() << "DB::insert failed on" << tableName << ":" << query.lastError().text() << "|" << query.lastQuery();
        return false;
    }
    return true;
}

bool DB::update(const QString &tableName, const FMH::MODEL &updateData, const QVariantMap &where)
{
    if (tableName.isEmpty()) {
        qWarning() << "DB::update: table name is empty";
        return false;
    } else if (updateData.isEmpty()) {
        qWarning() << "DB::update: update data is empty";
        return false;
    }

    if (!isValidIdentifier(tableName)) {
        qWarning() << "DB::update: invalid table name:" << tableName;
        return false;
    }

    QStringList set;
    const auto updateKeys = updateData.keys();
    for (const auto &key : updateKeys)
        set.append(FMH::MODEL_NAME[key] + " = ?");

    QStringList condition;
    const auto whereKeys = where.keys();
    for (const auto &key : whereKeys) {
        if (!isValidIdentifier(key)) {
            qWarning() << "DB::update: invalid WHERE column:" << key;
            return false;
        }
        condition.append(key + " = ?");
    }

    const QString sqlQueryString = "UPDATE " + tableName
                                   + " SET " + set.join(QStringLiteral(", "))
                                   + " WHERE " + condition.join(QStringLiteral(" AND "));

    QSqlQuery query(this->m_db);
    query.prepare(sqlQueryString);

    for (const auto &key : updateKeys)
        query.addBindValue(updateData[key]);
    for (const auto &key : whereKeys)
        query.addBindValue(where.value(key));

    if (!query.exec()) {
        qWarning() << "DB::update failed on" << tableName << ":" << query.lastError().text() << "|" << query.lastQuery();
        return false;
    }
    return true;
}

bool DB::update(const QString &table, const QString &column, const QVariant &newValue, const QVariant &op, const QString &id)
{
    const QString opStr = op.toString();
    if (!isValidIdentifier(table) || !isValidIdentifier(column) || !isValidIdentifier(opStr)) {
        qWarning() << "DB::update: invalid identifier(s):" << table << column << opStr;
        return false;
    }
    const QString sqlQueryString = QString("UPDATE %1 SET %2 = ? WHERE %3 = ?")
                                       .arg(table, column, opStr);

    QSqlQuery query(this->m_db);
    query.prepare(sqlQueryString);
    query.addBindValue(newValue);
    query.addBindValue(id);

    if (!query.exec()) {
        qWarning() << "DB::update failed on" << table << ":" << query.lastError().text() << "|" << query.lastQuery();
        return false;
    }
    return true;
}

bool DB::runQuery(const QString &queryTxt, const QVariantList &bindings)
{
    QSqlQuery query(this->m_db);
    query.prepare(queryTxt);
    for (int i = 0; i < bindings.size(); ++i)
        query.addBindValue(bindings.at(i));
    if (!query.exec()) {
        qWarning() << "DB::runQuery failed:" << query.lastError().text() << "|" << queryTxt;
        return false;
    }
    return true;
}

void DB::migrateSchema()
{
    runQuery(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS HISTORY_URLS ("
        "  url TEXT NOT NULL,"
        "  title TEXT,"
        "  visit_count INTEGER NOT NULL DEFAULT 1,"
        "  last_visit TEXT NOT NULL,"
        "  PRIMARY KEY(url)"
        ")"));

    runQuery(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS HISTORY_VISITS ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  url TEXT NOT NULL,"
        "  visit_time TEXT NOT NULL"
        ")"));

    runQuery(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS RECENTLY_CLOSED ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  urls TEXT NOT NULL,"
        "  closeddate TEXT NOT NULL"
        ")"));

    {
        auto countNew = getQuery(QStringLiteral("SELECT COUNT(*) FROM HISTORY_URLS"));
        if (countNew.exec() && countNew.next() && countNew.value(0).toInt() == 0) {
            auto hasOld = getQuery(
                QStringLiteral("SELECT COUNT(*) FROM sqlite_master "
                               "WHERE type='table' AND name='HISTORY'"));
            if (hasOld.exec() && hasOld.next() && hasOld.value(0).toInt() > 0) {
                runQuery(QStringLiteral(
                    "INSERT OR IGNORE INTO HISTORY_URLS(url, title, visit_count, last_visit) "
                    "SELECT url, title, 1, COALESCE(adddate, datetime('now')) FROM HISTORY"));
                runQuery(QStringLiteral(
                    "INSERT OR IGNORE INTO HISTORY_VISITS(url, visit_time) "
                    "SELECT url, COALESCE(adddate, datetime('now')) FROM HISTORY"));
                qInfo() << "DB: migrated legacy HISTORY rows to HISTORY_URLS + HISTORY_VISITS";
            }
        }
    }
    // Always drop the legacy table — prevents it from re-seeding HISTORY_URLS
    // on any startup where the table happens to exist and HISTORY_URLS is empty
    // (e.g. after the user clears browsing history).
    runQuery(QStringLiteral("DROP TABLE IF EXISTS HISTORY"));
}

bool DB::remove(const QString &tableName, const FMH::MODEL &removeData)
{
    if (tableName.isEmpty()) {
        qWarning() << "DB::remove: table name is empty";
        return false;

    } else if (removeData.isEmpty()) {
        qWarning() << "DB::remove: remove data is empty";
        return false;
    }

    if (!isValidIdentifier(tableName)) {
        qWarning() << "DB::remove: invalid table name:" << tableName;
        return false;
    }

    QStringList conditions;
    const auto keys = removeData.keys();
    for (const auto &key : keys)
        conditions.append(FMH::MODEL_NAME[key] + " = ?");

    const QString sqlQueryString = "DELETE FROM " + tableName
                                   + " WHERE " + conditions.join(QStringLiteral(" AND "));

    QSqlQuery query(this->m_db);
    query.prepare(sqlQueryString);

    for (const auto &key : keys)
        query.addBindValue(removeData[key]);

    if (!query.exec()) {
        qWarning() << "DB::remove failed on" << tableName << ":" << query.lastError().text() << "|" << query.lastQuery();
        return false;
    }
    return true;
}
