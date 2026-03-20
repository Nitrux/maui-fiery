#include "passwordmanager.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>

extern "C" {
#include <libsecret/secret.h>
}

// ── libsecret schema ─────────────────────────────────────────────────────────

static const SecretSchema *fierySchema()
{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
    static const SecretSchema s = {
        "org.maui.fiery.password",
        SECRET_SCHEMA_NONE,
        {
            { "host",     SECRET_SCHEMA_ATTRIBUTE_STRING },
            { "username", SECRET_SCHEMA_ATTRIBUTE_STRING },
            { nullptr,    SECRET_SCHEMA_ATTRIBUTE_STRING }
        }
    };
#pragma GCC diagnostic pop
    return &s;
}

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

    // Move each password into the system keyring.
    for (const Row &row : rows) {
        if (row.password.isEmpty())
            continue;

        GError *error = nullptr;
        const QString label = QStringLiteral("Fiery: %1 @ %2").arg(row.username, row.host);
        secret_password_store_sync(
            fierySchema(), SECRET_COLLECTION_DEFAULT,
            label.toUtf8().constData(),
            row.password.toUtf8().constData(),
            nullptr, &error,
            "host",     row.host.toUtf8().constData(),
            "username", row.username.toUtf8().constData(),
            nullptr);

        if (error) {
            qWarning() << "PasswordManager: migration failed for" << row.host << ":" << error->message;
            g_error_free(error);
        }
    }

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

    // Password in the system keyring (encrypted at rest, unlocked by the user's login session).
    GError *error = nullptr;
    const QString label = QStringLiteral("Fiery: %1 @ %2").arg(username, host);
    secret_password_store_sync(
        fierySchema(), SECRET_COLLECTION_DEFAULT,
        label.toUtf8().constData(),
        password.toUtf8().constData(),
        nullptr, &error,
        "host",     host.toUtf8().constData(),
        "username", username.toUtf8().constData(),
        nullptr);

    if (error) {
        qWarning() << "PasswordManager::save (keyring) failed:" << error->message;
        g_error_free(error);
    } else {
        Q_EMIT entriesChanged();
    }
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

    // Password from keyring.
    GError *error = nullptr;
    secret_password_clear_sync(
        fierySchema(), nullptr, &error,
        "host",     host.toUtf8().constData(),
        "username", username.toUtf8().constData(),
        nullptr);

    if (error) {
        qWarning() << "PasswordManager::remove (keyring) failed:" << error->message;
        g_error_free(error);
    } else {
        Q_EMIT entriesChanged();
    }
}

QVariantList PasswordManager::find(const QString &host) const
{
    QVariantList result;
    GError *error = nullptr;

    GHashTable *attrs = secret_attributes_build(
        fierySchema(),
        "host", host.toUtf8().constData(),
        nullptr);

    GList *items = secret_service_search_sync(
        nullptr, fierySchema(), attrs,
        static_cast<SecretSearchFlags>(
            SECRET_SEARCH_ALL | SECRET_SEARCH_UNLOCK | SECRET_SEARCH_LOAD_SECRETS),
        nullptr, &error);

    g_hash_table_unref(attrs);

    if (error) {
        qWarning() << "PasswordManager::find failed:" << error->message;
        g_error_free(error);
        return result;
    }

    for (GList *l = items; l; l = l->next) {
        SecretItem  *item      = SECRET_ITEM(l->data);
        SecretValue *val       = secret_item_get_secret(item);
        GHashTable  *itemAttrs = secret_item_get_attributes(item);

        if (itemAttrs) {
            QVariantMap entry;
            const char *un = static_cast<const char *>(g_hash_table_lookup(itemAttrs, "username"));
            entry[QStringLiteral("username")] = QString::fromUtf8(un ? un : "");
            if (val)
                entry[QStringLiteral("password")] = QString::fromUtf8(secret_value_get(val, nullptr));
            result.append(entry);
            g_hash_table_unref(itemAttrs);
        }

        if (val) secret_value_unref(val);
    }

    g_list_free_full(items, g_object_unref);
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
