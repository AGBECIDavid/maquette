#pragma once

#include <QHash>
#include <QPainterPath>
#include <QQuickPaintedItem>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class MapData;

// La carte, dessinée au QPainter : aucun shader, aucune tuile, aucun réseau.
// Même règle que le reste de l'IHM — la cible n'a peut-être pas de GPU, et ce
// qui passe par QPainter s'affiche à l'identique en rendu logiciel.
//
// Elle ne décide de rien : ce qu'elle montre vient de Navigation (carte,
// itinéraires, destination) ; où elle regarde, de ses propriétés, que l'écran
// anime (centre, zoom, rotation). La position de la navette est elle aussi une
// propriété, pour que l'écran puisse l'interpoler entre deux mesures GPS.
class MapView : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(double centerX MEMBER m_cx WRITE setCenterX NOTIFY viewChanged)
    Q_PROPERTY(double centerY MEMBER m_cy WRITE setCenterY NOTIFY viewChanged)
    Q_PROPERTY(double zoom MEMBER m_zoom WRITE setZoom NOTIFY viewChanged)          // pixels par mètre
    Q_PROPERTY(double bearing MEMBER m_bearing WRITE setBearing NOTIFY viewChanged) // cap en haut de l'écran, degrés
    // Où le centre de la vue tombe à l'écran (fraction de la largeur, de la
    // hauteur) : en guidage, la navette se place bas, pour voir loin devant.
    Q_PROPERTY(double anchorX MEMBER m_ax WRITE setAnchorX NOTIFY viewChanged)
    Q_PROPERTY(double anchorY MEMBER m_ay WRITE setAnchorY NOTIFY viewChanged)

    Q_PROPERTY(double vehicleX MEMBER m_vx WRITE setVehicleX NOTIFY viewChanged)
    Q_PROPERTY(double vehicleY MEMBER m_vy WRITE setVehicleY NOTIFY viewChanged)
    Q_PROPERTY(double vehicleHeading MEMBER m_vh WRITE setVehicleHeading NOTIFY viewChanged)
    Q_PROPERTY(QString selectedPlace MEMBER m_selected WRITE setSelectedPlace NOTIFY viewChanged)

    Q_PROPERTY(double metersPerPixel READ metersPerPixel NOTIFY viewChanged)
    // Temps moyen d'un dessin complet de la carte, en ms (recette).
    Q_PROPERTY(double paintMs READ paintMs)

public:
    explicit MapView(QQuickItem *parent = nullptr);
    void paint(QPainter *painter) override;
    void componentComplete() override;

    void setCenterX(double v) { set(m_cx, v); }
    void setCenterY(double v) { set(m_cy, v); }
    void setZoom(double v) { set(m_zoom, qBound(0.03, v, 8.0)); }
    void setBearing(double v) { set(m_bearing, v); }
    void setAnchorX(double v) { set(m_ax, v); }
    void setAnchorY(double v) { set(m_ay, v); }
    void setVehicleX(double v) { set(m_vx, v); }
    void setVehicleY(double v) { set(m_vy, v); }
    void setVehicleHeading(double v) { set(m_vh, v); }
    void setSelectedPlace(const QString &id);
    double metersPerPixel() const { return 1.0 / m_zoom; }
    double paintMs() const { return m_paintCount ? m_paintTotal / m_paintCount : 0; }
    Q_INVOKABLE void resetPaintStats() { m_paintTotal = 0; m_paintCount = 0; }

    Q_INVOKABLE QPointF toScreen(double x, double y) const;
    Q_INVOKABLE QPointF toMap(double px, double py) const;
    // Centre et zoom pour voir tout un rectangle de carte, en laissant libres
    // les marges données (panneaux posés sur la carte).
    Q_INVOKABLE QVariantMap fit(const QRectF &mapRect, double left, double top,
                                double right, double bottom) const;
    Q_INVOKABLE QRectF routeBounds() const;

signals:
    void viewChanged();

private:
    void set(double &field, double v);
    QTransform world() const;
    void drawBase(QPainter *p, const MapData &map, const QRectF &visible) const;
    void drawRoutes(QPainter *p) const;
    void drawLabels(QPainter *p, const MapData &map) const;
    void drawMarkers(QPainter *p) const;
    void drawVehicle(QPainter *p) const;
    void haloText(QPainter *p, const QPointF &at, const QString &text, const QColor &color,
                  bool centered = false) const;

    double m_cx = 0, m_cy = 0, m_zoom = 0.3, m_bearing = 0;
    double m_ax = 0.5, m_ay = 0.5;
    double m_vx = 0, m_vy = 0, m_vh = 0;
    QString m_selected;
    double m_paintTotal = 0;
    int m_paintCount = 0;

    // Caches : les tracés de route ne changent jamais (coordonnées de carte),
    // les contours de texte ne dépendent que du texte et de la police. Les
    // refaire à chaque image coûtait l'essentiel du dessin.
    mutable QVector<QPainterPath> m_roadPaths;
    mutable QHash<QString, QPainterPath> m_textPaths;
};
