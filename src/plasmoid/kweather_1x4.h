/*
    SPDX-FileCopyrightText: 2020 HanY <hanyoung@protonmail.com>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

#ifndef KWEATHER_1X4_H
#define KWEATHER_1X4_H
#include <KWeatherCore/WeatherForecast>
#include <Plasma/Applet>
class KWeather_1x4 : public Plasma::Applet
{
    Q_OBJECT
    Q_PROPERTY(bool needLocation READ needLocation NOTIFY needLocationChanged)
    Q_PROPERTY(QString location READ location NOTIFY locationChanged)
    Q_PROPERTY(qreal temp READ temp NOTIFY updated)
    Q_PROPERTY(QString desc READ desc NOTIFY updated)
    Q_PROPERTY(QString weatherIcon READ weatherIcon NOTIFY updated)
    Q_PROPERTY(qreal humidity READ humidity NOTIFY updated)
    Q_PROPERTY(qreal precipitation READ precipitation NOTIFY updated)
public:
    KWeather_1x4(QObject *parent, const QVariantList &args);
    QString location() const;
    QString desc() const;
    qreal temp() const;
    QString weatherIcon() const;
    qreal humidity() const;
    qreal precipitation() const;
    bool needLocation() const {
        return m_needLocation;
    }

    Q_INVOKABLE QStringList locationsInSystem();
    Q_INVOKABLE void setLocation(const QString &location);
signals:
    void locationChanged();
    void updated();
    void needLocationChanged();
private:
    void update();
    bool hasForecast() const;
    const KWeatherCore::HourlyWeatherForecast &getFirst() const;

    bool m_needLocation = true;
    QString m_location;
    double m_latitude, m_longitude;
    QExplicitlySharedDataPointer<KWeatherCore::WeatherForecast> m_forecast;
};

#endif
