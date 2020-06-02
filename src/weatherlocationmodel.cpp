/*
 * Copyright 2020 Han Young <hanyoung@protonmail.com>
 * Copyright 2020 Devin Lin <espidev@gmail.com>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "weatherlocationmodel.h"
#include "abstractweatherapi.h"
#include "abstractweatherforecast.h"
#include "geoiplookup.h"
#include "geotimezone.h"
#include "global.h"
#include "locationquerymodel.h"
#include "nmisunriseapi.h"
#include "nmiweatherapi2.h"
#include "owmweatherapi.h"
#include "weatherdaymodel.h"
#include "weatherhourmodel.h"

#include <KConfigCore/KConfigGroup>
#include <KConfigCore/KSharedConfig>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QQmlEngine>
#include <QTimeZone>
#include <utility>

const QString WEATHER_LOCATIONS_CFG_GROUP = "WeatherLocations";
const QString WEATHER_LOCATIONS_CFG_KEY = "locationsList";

/* ~~~ WeatherLocation ~~~ */
WeatherLocation::WeatherLocation() {
    this->weatherDayListModel_ = new WeatherDayListModel(this);
    this->weatherHourListModel_ = new WeatherHourListModel(this);
    this->lastUpdated_ = QDateTime::currentDateTime();
}

WeatherLocation::WeatherLocation(AbstractWeatherAPI *weatherBackendProvider,
                                 QString locationId,
                                 QString locationName,
                                 QString timeZone,
                                 float latitude,
                                 float longitude,
                                 Kweather::Backend backend,
                                 AbstractWeatherForecast forecast)
    : backend_(backend)
    , locationName_(std::move(locationName))
    , timeZone_(std::move(timeZone))
    , latitude_(latitude)
    , longitude_(longitude)
    , locationId_(std::move(locationId))
    , forecast_(forecast)
    , weatherBackendProvider_(weatherBackendProvider)
{
    this->weatherDayListModel_ = new WeatherDayListModel(this);
    this->weatherHourListModel_ = new WeatherHourListModel(this);
    this->lastUpdated_ = forecast.timeCreated();

    // prevent segfaults from js garbage collection
    QQmlEngine::setObjectOwnership(this->weatherDayListModel_,
                                   QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(this->weatherHourListModel_, QQmlEngine::CppOwnership);

    determineCurrentForecast();

    connect(this->weatherBackendProvider(), &AbstractWeatherAPI::updated, this, &WeatherLocation::updateData, Qt::UniqueConnection);
}

WeatherLocation *WeatherLocation::fromJson(const QJsonObject &obj)
{
    AbstractWeatherAPI *api;
    Kweather::Backend backendEnum;
    if (obj["backend"].toInt() == 0) {
        api = new NMIWeatherAPI2(obj["locationId"].toString(), obj["timezone"].toString(), obj["latitude"].toDouble(), obj["longitude"].toDouble());
        backendEnum = Kweather::Backend::NMI;
    } else {
        api = new OWMWeatherAPI(obj["locationId"].toString(), obj["timezone"].toString(), obj["latitude"].toDouble(), obj["longitude"].toDouble());
        backendEnum = Kweather::Backend::OWM;
    }
    auto weatherLocation = new WeatherLocation(api,
                                               obj["locationId"].toString(),
                                               obj["locationName"].toString(),
                                               obj["timezone"].toString(),
                                               obj["latitude"].toDouble(),
                                               obj["longitude"].toDouble(),
                                               backendEnum,
                                               AbstractWeatherForecast());
    return weatherLocation;
}

QJsonObject WeatherLocation::toJson()
{
    QJsonObject obj;
    obj["locationId"] = locationId();
    obj["locationName"] = locationName();
    obj["latitude"] = latitude();
    obj["longitude"] = longitude();
    obj["timezone"] = timeZone_;
    obj["backend"] = static_cast<int>(backend_);
    return obj;
}

void WeatherLocation::updateData(AbstractWeatherForecast& fc)
{
    // only update if the forecast is newer
//    if (fc.timeCreated().toSecsSinceEpoch() < forecast_.timeCreated().toSecsSinceEpoch())
//        return;
    forecast_ = fc;
    determineCurrentForecast();
    lastUpdated_ = fc.timeCreated();

    emit weatherRefresh(forecast_);
    emit stopLoadingIndicator();
    writeToCache(forecast_);

    emit propertyChanged();
}

void WeatherLocation::determineCurrentForecast()
{
    delete currentWeather_;

    if (forecast().hourlyForecasts().count() == 0) {
        currentWeather_ = new WeatherHour();
    } else {
        long long minSecs = -1;
        QDateTime current = QDateTime::currentDateTime();

        // get closest forecast to current time
        for (auto forecast : forecast_.hourlyForecasts()) {
            if (minSecs == -1 || minSecs > llabs(forecast.date().secsTo(current))) {
                currentWeather_ = new WeatherHour(forecast);
                minSecs = llabs(forecast.date().secsTo(current));
            }
        }
    }
    QQmlEngine::setObjectOwnership(currentWeather_, QQmlEngine::CppOwnership); // prevent segfaults from js garbage collecting
    emit currentForecastChange();
}

void WeatherLocation::initData(AbstractWeatherForecast fc)
{
    forecast_ = fc;
    weatherBackendProvider_->setCurrentData(forecast_);
    weatherBackendProvider_->setCurrentSunriseData(fc.sunrise());
    determineCurrentForecast();
    emit weatherRefresh(forecast_);
    emit propertyChanged();
}

void WeatherLocation::update()
{
    weatherBackendProvider_->update();
}

void WeatherLocation::writeToCache(AbstractWeatherForecast& fc)
{
    QFile file;
    QString url = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir dir(url.append(QString("/cache"))); // create cache location
    if (!dir.exists())
        dir.mkpath(".");
    // should be this path: /home/user/.cache/kweather/cache/1234567 for
    // location with locationID 1234567
    file.setFileName(dir.path() + "/" + this->locationId());
    file.open(QIODevice::WriteOnly);
    file.write(convertToJson(fc).toJson(QJsonDocument::Compact)); // write json
    file.close();
}
QJsonDocument WeatherLocation::convertToJson(AbstractWeatherForecast& fc)
{
    QJsonDocument doc;
    doc.setObject(fc.toJson());
    return doc;
}

//void WeatherLocation::changeBackend(Kweather::Backend backend)
//{
//    if (backend != backend_) {
//        backend_ = backend;
//        AbstractWeatherAPI *tmp;
//        switch (backend_) {
//        case Kweather::Backend::OWM:
//            tmp = new OWMWeatherAPI(weatherBackendProvider_->locationName());
//            delete weatherBackendProvider_;
//            weatherBackendProvider_ = tmp;
//            this->update();
//            break;
//        case Kweather::Backend::NMI:
//            tmp = new NMIWeatherAPI2(weatherBackendProvider_->locationName());
//            delete weatherBackendProvider_;
//            weatherBackendProvider_ = tmp;
//            this->update();
//            break;
//        default:
//            return;
//        }
//    }
//}

WeatherLocation::~WeatherLocation()
{
    delete weatherBackendProvider_;
    delete geoTimeZone_;
}

/* ~~~ WeatherLocationListModel ~~~ */
WeatherLocationListModel::WeatherLocationListModel(QObject *parent)
{
    load();
}

void WeatherLocationListModel::load()
{
    // load locations from kconfig
    auto config = KSharedConfig::openConfig();
    KConfigGroup group = config->group(WEATHER_LOCATIONS_CFG_GROUP);
    QJsonDocument doc = QJsonDocument::fromJson(group.readEntry(WEATHER_LOCATIONS_CFG_KEY, "{}").toUtf8());
    for (QJsonValueRef r : doc.array()) {
        QJsonObject obj = r.toObject();
        locationsList.append(WeatherLocation::fromJson(obj));
    }
}

void WeatherLocationListModel::save()
{
    QJsonArray arr;
    for (auto lc : locationsList) {
        arr.push_back(lc->toJson());
    }
    QJsonObject obj;
    obj["list"] = arr;

    auto config = KSharedConfig::openConfig();
    KConfigGroup group = config->group(WEATHER_LOCATIONS_CFG_GROUP);
    group.writeEntry(WEATHER_LOCATIONS_CFG_KEY, QString(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
}

int WeatherLocationListModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return locationsList.size();
}

QVariant WeatherLocationListModel::data(const QModelIndex &index, int role) const
{
    return QVariant();
}

void WeatherLocationListModel::updateUi()
{
    emit dataChanged(createIndex(0, 0), createIndex(locationsList.count() - 1, 0));
    for (auto l : locationsList) {
        emit l->propertyChanged();
        l->weatherDayListModel()->updateUi();
        l->weatherHourListModel()->updateUi();
    }
}

void WeatherLocationListModel::insert(int index, WeatherLocation *weatherLocation)
{
    if ((index < 0) || (index > locationsList.count()))
        return;

    QQmlEngine::setObjectOwnership(weatherLocation, QQmlEngine::CppOwnership);
    emit beginInsertRows(QModelIndex(), index, index);
    locationsList.insert(index, weatherLocation);
    emit endInsertRows();

    save();
}

void WeatherLocationListModel::remove(int index)
{
    if ((index < 0) || (index >= locationsList.count()))
        return;

    emit beginRemoveRows(QModelIndex(), index, index);
    auto location = locationsList.at(index);
    locationsList.removeAt(index);
//    delete location; TODO deletion has a chance of causing segfaults
    emit endRemoveRows();

    save();
}

WeatherLocation *WeatherLocationListModel::get(int index)
{
    if ((index < 0) || (index >= locationsList.count()))
        return {};

    return locationsList.at(index);
}

void WeatherLocationListModel::move(int oldIndex, int newIndex)
{
    if (oldIndex < 0 || oldIndex >= locationsList.count() || newIndex < 0 || newIndex >= locationsList.count())
        return;
    locationsList.move(oldIndex, newIndex);
}

void WeatherLocationListModel::addLocation(LocationQueryResult *ret)
{
    qDebug() << "add location";
    auto locId = ret->geonameId(), locName = ret->name();
    auto lat = ret->latitude(), lon = ret->longitude();

    // obtain timezone
    auto *tz = new GeoTimeZone(ret->latitude(), ret->longitude());
    connect(tz, &GeoTimeZone::finished, this, [this, locId, locName, lat, lon, tz] {
        qDebug() << "obtained timezone data";

        Kweather::Backend backendEnum;
        AbstractWeatherAPI *api;

        // create backend provider
        QSettings qsettings;
        QString backend = qsettings.value("Global/defaultBackend", Kweather::API_NMI).toString();
        if (backend == Kweather::API_NMI) {
            api = new NMIWeatherAPI2(locId, tz->getTimeZone(), lat, lon);
            backendEnum = Kweather::Backend::NMI;
        } else if (backend == Kweather::API_OWM) {
            api = new OWMWeatherAPI(locId, tz->getTimeZone(), lat, lon);
            backendEnum = Kweather::Backend::OWM;
        } else {
            api = new NMIWeatherAPI2(locId, tz->getTimeZone(), lat, lon);
            backendEnum = Kweather::Backend::NMI;
        }

        // add location
        auto* location = new WeatherLocation(api, locId, locName, tz->getTimeZone(), lat, lon, backendEnum);
        location->update();

        insert(this->locationsList.count(), location);
    });
}

void WeatherLocationListModel::requestCurrentLocation()
{
    geoPtr = new GeoIPLookup();
    connect(geoPtr, &GeoIPLookup::finished, this, &WeatherLocationListModel::addCurrentLocation);
}

void WeatherLocationListModel::addCurrentLocation()
{
    // default location, use timestamp as id
    long id = QDateTime::currentSecsSinceEpoch();

    auto api = new NMIWeatherAPI2(QString::number(id), geoPtr->timeZone(), geoPtr->latitude(), geoPtr->longitude());
    auto location = new WeatherLocation(api, QString::number(id), geoPtr->name(), geoPtr->timeZone(), geoPtr->latitude(), geoPtr->longitude());
    location->update();

    insert(0, location);
}
