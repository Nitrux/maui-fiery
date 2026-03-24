#include "widevineinstaller.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>

static constexpr char CDM_TAR_URL[] =
    "https://github.com/UriHerrera/storage/raw/master/Files/WidevineCdm.tar";

// ─────────────────────────────────────────────────────────────────────────────

WidevineInstaller &WidevineInstaller::instance()
{
    static WidevineInstaller inst;
    return inst;
}

WidevineInstaller::WidevineInstaller(QObject *parent)
    : QObject(parent)
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                         + QLatin1Char('/') + QCoreApplication::applicationName();

    m_cdmDir       = base + QStringLiteral("/WidevineCdm");
    m_destPath     = m_cdmDir + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
    m_manifestPath = m_cdmDir + QStringLiteral("/manifest.json");
    m_tempTarPath  = QDir::tempPath() + QStringLiteral("/fiery_widevine.tar");

    if (QFile::exists(m_destPath) && QFile::exists(m_manifestPath))
        m_state = State::Ready;
}

// ── Public API ────────────────────────────────────────────────────────────────

bool WidevineInstaller::isInstalled() const
{
    return QFile::exists(m_destPath) && QFile::exists(m_manifestPath);
}

QString WidevineInstaller::installedPath() const
{
    return isInstalled() ? m_cdmDir : QString{};
}

void WidevineInstaller::install()
{
    if (m_state == State::Downloading || m_state == State::Extracting
            || m_state == State::Ready)
        return;

    setProgress(0);
    startDownload();
}

void WidevineInstaller::cancel()
{
    cleanup();
    setState(State::Idle);
    setStatusMessage(tr("Cancelled."));
}

void WidevineInstaller::startDownload()
{
    m_buffer.clear();

    QNetworkRequest req(QUrl(QString::fromLatin1(CDM_TAR_URL)));
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);

    setState(State::Downloading);
    setStatusMessage(tr("Downloading Widevine CDM…"));

    m_reply = m_nam.get(req);

    connect(m_reply, &QNetworkReply::downloadProgress,
            this, &WidevineInstaller::onDownloadProgress);
    connect(m_reply, &QNetworkReply::finished,
            this, &WidevineInstaller::onDownloadFinished);
    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        m_buffer.append(m_reply->readAll());
    });
}

void WidevineInstaller::onDownloadProgress(qint64 received, qint64 total)
{
    if (total > 0)
        setProgress(static_cast<int>(received * 100 / total));
}

void WidevineInstaller::onDownloadFinished()
{
    const QNetworkReply::NetworkError netErr = m_reply->error();
    const int httpStatus =
        m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    m_reply->deleteLater();
    m_reply = nullptr;

    if (netErr != QNetworkReply::NoError) {
        fail(tr("Download failed (HTTP %1).").arg(httpStatus));
        return;
    }
    if (m_buffer.isEmpty()) {
        fail(tr("Download produced an empty file."));
        return;
    }

    QFile f(m_tempTarPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        fail(tr("Cannot write temp file: %1").arg(f.errorString()));
        return;
    }
    f.write(m_buffer);
    f.close();
    m_buffer.clear();

    extractTar(m_tempTarPath);
}

void WidevineInstaller::extractTar(const QString &tarPath)
{
    setState(State::Extracting);
    setStatusMessage(tr("Extracting Widevine CDM…"));
    setProgress(0);

    const QString parentDir = QFileInfo(m_cdmDir).absolutePath();
    QDir().mkpath(parentDir);

    m_process = new QProcess(this);
    m_process->setProgram(QStringLiteral("tar"));
    m_process->setArguments({
        QStringLiteral("-xf"), tarPath,
        QStringLiteral("-C"),  parentDir
    });

    connect(m_process,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &WidevineInstaller::onExtractionFinished);

    m_process->start();
}

void WidevineInstaller::onExtractionFinished(int exitCode, QProcess::ExitStatus)
{
    const QByteArray errOutput = m_process->readAllStandardError();
    m_process->deleteLater();
    m_process = nullptr;

    QFile::remove(m_tempTarPath);

    if (exitCode != 0) {
        qWarning() << "WidevineInstaller: tar failed:" << errOutput;
        fail(tr("Extraction failed (exit %1).").arg(exitCode));
        return;
    }

    if (!QFile::exists(m_destPath)) {
        fail(tr("libwidevinecdm.so not found after extraction."));
        return;
    }

    // Ensure the library is executable.
    QFile(m_destPath).setPermissions(
        QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
        QFile::ReadGroup | QFile::ExeGroup |
        QFile::ReadOther | QFile::ExeOther);

    setProgress(100);
    setState(State::Ready);
    setStatusMessage(tr("Widevine CDM installed. Restart Fiery to enable DRM."));
    Q_EMIT installed();
}

void WidevineInstaller::setState(State s)
{
    if (m_state == s) return;
    m_state = s;
    Q_EMIT stateChanged();
}

void WidevineInstaller::setProgress(int p)
{
    if (m_progress == p) return;
    m_progress = p;
    Q_EMIT progressChanged();
}

void WidevineInstaller::setStatusMessage(const QString &msg)
{
    if (m_statusMessage == msg) return;
    m_statusMessage = msg;
    Q_EMIT statusMessageChanged();
}

void WidevineInstaller::fail(const QString &reason)
{
    qWarning() << "WidevineInstaller:" << reason;
    cleanup();
    setState(State::Failed);
    setStatusMessage(reason);
}

void WidevineInstaller::cleanup()
{
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    if (m_process) {
        m_process->kill();
        m_process->deleteLater();
        m_process = nullptr;
    }
    m_buffer.clear();
    QFile::remove(m_tempTarPath);
}
