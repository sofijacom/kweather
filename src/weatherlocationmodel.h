#ifndef WEATHERLOCATIONMODEL_H
#define WEATHERLOCATIONMODEL_H
#include "abstractweatherforecast.h"
#include <QAbstractListModel>
#include <QDebug>
#include <QObject>

class WeatherDayListModel;
class WeatherHourListModel;
class AbstractWeatherAPI;
class NMIWeatherAPI;
class AbstractWeatherForecast;

class WeatherLocation : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name READ locationName NOTIFY propertyChanged)
    Q_PROPERTY(WeatherDayListModel *dayListModel READ weatherDayListModel NOTIFY propertyChanged)
    Q_PROPERTY(WeatherHourListModel *hourListModel READ weatherHourListModel NOTIFY propertyChanged)
    Q_PROPERTY(AbstractWeatherForecast *currentForecast READ currentForecast NOTIFY currentForecastChange)

public:
    explicit WeatherLocation();
    explicit WeatherLocation(NMIWeatherAPI *weatherBackendProvider, QString locationName, float latitude, float longitude);
    explicit WeatherLocation(NMIWeatherAPI *weatherBackendProvider, QString locationName, float latitude, float longitude, QList<AbstractWeatherForecast *> forecasts_);

    inline QString locationName()
    {
        return locationName_;
    }
    inline float latitude()
    {
        return latitude_;
    }
    inline float longitude()
    {
        return longitude_;
    }
    inline AbstractWeatherForecast *currentForecast()
    {
        return currentForecast_;
    }
    inline WeatherDayListModel *weatherDayListModel()
    {
        return weatherDayListModel_;
    }
    inline WeatherHourListModel *weatherHourListModel()
    {
        return weatherHourListModel_;
    }
    inline QList<AbstractWeatherForecast *> forecasts()
    {
        return forecasts_;
    }
    inline NMIWeatherAPI *weatherBackendProvider()
    {
        return weatherBackendProvider_;
    }
    void determineCurrentForecast();

public slots:
    void updateData(QList<AbstractWeatherForecast *> fc);

signals:
    void weatherRefresh(QList<AbstractWeatherForecast *> fc); // sent when weather data is refreshed
    void currentForecastChange();
    void propertyChanged(); // avoid warning

private:
    QString locationName_;
    float latitude_, longitude_;

    WeatherDayListModel *weatherDayListModel_;
    WeatherHourListModel *weatherHourListModel_;

    NMIWeatherAPI *weatherBackendProvider_; // OpenWeatherMap is not supported now anyway

    AbstractWeatherForecast *currentForecast_;
    QList<AbstractWeatherForecast *> forecasts_;
};

class WeatherLocationListModel : public QAbstractListModel
{
    Q_OBJECT
public:
    explicit WeatherLocationListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent) const override;
    QVariant data(const QModelIndex &index, int role) const override;

    Q_INVOKABLE void updateUi();

    Q_INVOKABLE void insert(int index, WeatherLocation *weatherLocation);
    Q_INVOKABLE void remove(int index);
    Q_INVOKABLE void move(int oldIndex, int newIndex);
    Q_INVOKABLE WeatherLocation *get(int index);
    inline QList<WeatherLocation *> &getList()
    {
        return locationsList;
    };

private:
    QList<WeatherLocation *> locationsList;
};

#endif // WEATHERLOCATIONMODEL_H
