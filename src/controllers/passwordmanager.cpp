#include "passwordmanager.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>

#include <MauiKit4/Accounts/mauisecretstore.h>

// ── Singleton ────────────────────────────────────────────────────────────────

PasswordManager &PasswordManager::instance()
{
    static PasswordManager inst;
    return inst;
}

PasswordManager::PasswordManager(QObject *parent)
    : QObject(parent)
{
    openDB();
    prepareDB();
    MauiSecretStore::instance()->migrateLegacy(QStringLiteral("org.maui.fiery.password"), {QStringLiteral("host"), QStringLiteral("username")}, QStringLiteral("fiery"), QStringLiteral("password"));
}

PasswordManager::~PasswordManager()
{
    if (m_db.isOpen())
        m_db.close();
}

// ── SQLite (metadata only) ───────────────────────────────────────────────────

void PasswordManager::openDB()
{
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                            + QLatin1Char('/') + QCoreApplication::applicationName();
    QDir().mkpath(dataDir);

    const QString dbPath = dataDir + QStringLiteral("/passwords.db");

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("fiery-passwords"));
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qCritical() << "PasswordManager: failed to open database:" << m_db.lastError().text();
        return;
    }

    QFile::setPermissions(dbPath, QFile::ReadOwner | QFile::WriteOwner);

    QSqlQuery pragma(m_db);
    pragma.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    pragma.exec(QStringLiteral("PRAGMA synchronous=NORMAL"));
}

void PasswordManager::prepareDB()
{
    // Create the metadata table (no password column).
    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral(
            "CREATE TABLE IF NOT EXISTS PASSWORDS ("
            "  host     TEXT NOT NULL,"
            "  username TEXT NOT NULL,"
            "  created  TEXT,"
            "  PRIMARY KEY (host, username)"
            ")")))
        qWarning() << "PasswordManager: schema creation failed:" << q.lastError().text();

    // Detect old schema that stored plain-text passwords and migrate them.
    // The check query must be fully closed before migration runs, otherwise
    // its read cursor holds a table lock that prevents DROP TABLE.
    bool needsMigration = false;
    {
        QSqlQuery check(m_db);
        check.exec(QStringLiteral("SELECT password FROM PASSWORDS LIMIT 1"));
        needsMigration = !check.lastError().isValid();
        check.finish();
    }

    if (needsMigration)
        migrateFromPlainText();
}

void PasswordManager::migrateFromPlainText()
{

    // Read all rows into memory first so the cursor is closed before we
    // attempt to drop the table (SQLite rejects DROP on a table with an
    // active read cursor).
    struct Row { QString host, username, password; };
    QList<Row> rows;
    {
        QSqlQuery q(m_db);
        if (!q.exec(QStringLiteral("SELECT host, username, password FROM PASSWORDS"))) {
            qWarning() << "PasswordManager: migration read failed:" << q.lastError().text();
            return;
        }
        while (q.next())
            rows.append({ q.value(0).toString(), q.value(1).toString(), q.value(2).toString() });
        q.finish(); // explicitly release the read cursor
    }

    bool migrationSucceeded = true;
    for (const Row &row : rows) {
        if (row.password.isEmpty())
            continue;
        // Secret Service attributes cannot contain control characters.
        if (row.host.contains(QChar(0)) || row.username.contains(QChar(0))) {
            migrationSucceeded = false;
            continue;
        }

        const bool migrated = MauiSecretStore::instance()->save(QStringLiteral("fiery"), QStringLiteral("password"), QVariantMap{{QStringLiteral("host"), row.host}, {QStringLiteral("username"), row.username}}, row.password, QStringLiteral("Fiery: %1 @ %2").arg(row.username, row.host));
        if (!migrated) {
            migrationSucceeded = false;
            qWarning() << "PasswordManager: migration failed for" << row.host;
        }
    }

    if (!migrationSucceeded)
        return;

    // Recreate the table without the password column.
    // Drop any leftover temp table from a previous failed attempt first.
    bool ok = m_db.transaction();
    QSqlQuery r(m_db);
    ok = ok && r.exec(QStringLiteral("DROP TABLE IF EXISTS PASSWORDS_NEW"));
    ok = ok && r.exec(QStringLiteral(
        "CREATE TABLE PASSWORDS_NEW ("
        "  host TEXT NOT NULL, username TEXT NOT NULL, created TEXT,"
        "  PRIMARY KEY (host, username))"));
    ok = ok && r.exec(QStringLiteral(
        "INSERT INTO PASSWORDS_NEW SELECT host, username, created FROM PASSWORDS"));
    ok = ok && r.exec(QStringLiteral("DROP TABLE PASSWORDS"));
    ok = ok && r.exec(QStringLiteral("ALTER TABLE PASSWORDS_NEW RENAME TO PASSWORDS"));

    if (ok) {
        m_db.commit();
    } else {
        qWarning() << "PasswordManager: migration schema update failed:" << r.lastError().text();
        m_db.rollback();
    }
}

// ── Public API ───────────────────────────────────────────────────────────────

void PasswordManager::save(const QString &host, const QString &username, const QString &password)
{
    // Secret Service attributes cannot contain control characters.
    if (host.contains(QChar(0)) || username.contains(QChar(0))) {
        qWarning() << "PasswordManager::save: null byte in host or username, rejecting";
        return;
    }

    // Metadata in SQLite.
    {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral(
            "INSERT OR REPLACE INTO PASSWORDS (host, username, created)"
            " VALUES (?, ?, datetime('now'))"));
        q.addBindValue(host);
        q.addBindValue(username);
        if (!q.exec())
            qWarning() << "PasswordManager::save (metadata) failed:" << q.lastError().text();
    }

    const bool stored = MauiSecretStore::instance()->save(QStringLiteral("fiery"), QStringLiteral("password"), QVariantMap{{QStringLiteral("host"), host}, {QStringLiteral("username"), username}}, password, QStringLiteral("Fiery: %1 @ %2").arg(username, host));
    if (!stored)
        qWarning() << "PasswordManager: keyring save failed for" << host;
    else
        Q_EMIT entriesChanged();
}

void PasswordManager::remove(const QString &host, const QString &username)
{
    // Metadata from SQLite.
    {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("DELETE FROM PASSWORDS WHERE host = ? AND username = ?"));
        q.addBindValue(host);
        q.addBindValue(username);
        if (!q.exec())
            qWarning() << "PasswordManager::remove (metadata) failed:" << q.lastError().text();
    }

    if (!MauiSecretStore::instance()->remove(QStringLiteral("fiery"), QStringLiteral("password"), QVariantMap{{QStringLiteral("host"), host}, {QStringLiteral("username"), username}}))
        qWarning() << "PasswordManager: keyring removal failed for" << host;
    else
        Q_EMIT entriesChanged();
}

QVariantList PasswordManager::find(const QString &host) const
{
    QVariantList result;
    for (const auto &value : MauiSecretStore::instance()->findAll(QStringLiteral("fiery"), QStringLiteral("password"), QVariantMap{{QStringLiteral("host"), host}})) {
        const auto stored = value.toMap();
        result.append(QVariantMap{{QStringLiteral("username"), stored.value(QStringLiteral("username"))}, {QStringLiteral("password"), stored.value(QStringLiteral("secret"))}});
    }
    return result;
}

bool PasswordManager::hasCredentials(const QString &host) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT COUNT(*) FROM PASSWORDS WHERE host = ?"));
    q.addBindValue(host);

    if (!q.exec() || !q.next())
        return false;

    return q.value(0).toInt() > 0;
}

void PasswordManager::requestSave(const QString &host, const QString &username, const QString &password)
{
    Q_EMIT saveRequested(host, username, password);
}

QVariantList PasswordManager::entries() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    if (!q.exec(QStringLiteral(
            "SELECT host, username, created"
            " FROM PASSWORDS ORDER BY host, username"))) {
        qWarning() << "PasswordManager::entries failed:" << q.lastError().text();
        return result;
    }

    while (q.next()) {
        QVariantMap entry;
        entry[QStringLiteral("host")]     = q.value(0).toString();
        entry[QStringLiteral("username")] = q.value(1).toString();
        entry[QStringLiteral("created")]  = q.value(2).toString();
        result.append(entry);
    }
    return result;
}
