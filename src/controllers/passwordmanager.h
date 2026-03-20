#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>

class PasswordManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged FINAL)

public:
    static PasswordManager &instance();

    // Returns metadata (host, username, created) from SQLite — no keyring access.
    QVariantList entries() const;

public Q_SLOTS:
    // Stores metadata in SQLite and the password in the system keyring.
    void save(const QString &host, const QString &username, const QString &password);

    // Deletes from both SQLite and the system keyring.
    void remove(const QString &host, const QString &username);

    // Fetches credentials from the keyring for the given host.
    // May trigger a keyring unlock prompt if the collection is locked.
    QVariantList find(const QString &host) const;

    // Returns true if any credentials are stored for the given host.
    // Checks SQLite only — never touches the keyring.
    bool hasCredentials(const QString &host) const;

    // Called from QML when JS detects a form submission with credentials.
    // Emits saveRequested so main.qml can prompt the user.
    void requestSave(const QString &host, const QString &username, const QString &password);

Q_SIGNALS:
    void entriesChanged();
    void saveRequested(const QString &host, const QString &username, const QString &password);

private:
    explicit PasswordManager(QObject *parent = nullptr);
    ~PasswordManager();

    void openDB();
    void prepareDB();
    void migrateFromPlainText();

    QSqlDatabase m_db;
};
