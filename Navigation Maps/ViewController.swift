//
//  ViewController.swift
//  Navigation Maps
//
//  Created by Noel Velasco on 8/31/21.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController {

  @IBOutlet weak var mapView: MKMapView!

  private let lat: String = "14.5511196"
  private let lng: String = "121.0242031"

  private let locationManager = CLLocationManager()

  private var isMapLoaded: Bool = false
  private var timer = Timer()
//  var currentLocation: CLLocationCoordinate2D?
//  var previousLocation: CLLocationCoordinate2D?
  private var myLocationAnnotation = MKPointAnnotation()
  private var instruction: String = "" {
    didSet {
      speech()
    }
  }
  private var distance: Int = 0

  override func viewDidLoad() {
    super.viewDidLoad()

    mapView.isHidden = true
    accessLocation()

  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if CLLocationManager.locationServicesEnabled() {
      locationManager.startUpdatingLocation()
    }
  }

  private func accessLocation() {
    guard CLLocationManager.locationServicesEnabled() else {
      return
    }
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.requestAlwaysAuthorization()
  }

  private func updateMap(route: MKRoute, animated: Bool) {
    for overlay in mapView.overlays {
      mapView.removeOverlay(overlay)
    }
    mapView.addOverlay(route.polyline, level: .aboveRoads)
    if !animated {
      let rect = route.polyline.boundingMapRect
      mapView.setRegion(MKCoordinateRegion(rect), animated: false)
      mapView.isHidden = false
    }

    if let step = route.steps.first?.instructions, !step.isEmpty {
      if instruction != step {
        instruction = step
      }

      if let dist = route.steps.first?.distance {
        distance = Int(dist)
      } else {
        distance = 0
      }
    } else if route.steps.count > 1 {
      if route.steps[1].instructions != instruction {
        instruction = route.steps[1].instructions
      }

      distance = Int(route.steps[1].distance)
    }
  }

  @objc private func speech() {
    timer.invalidate()

    var instruct = ""
    if distance > 0 {
      instruct = "In \(distance) meters, \(instruction)"
    } else {
      instruct = instruction
    }

    let speechInstruction = AVSpeechUtterance(string: "\(instruct)")
    speechInstruction.voice = AVSpeechSynthesisVoice(language: "en-US")
    speechInstruction.rate = 0.5

    let synthesizer = AVSpeechSynthesizer()
    synthesizer.speak(speechInstruction)

    timer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(speech), userInfo: nil, repeats: true)
  }

  private func mapDirection(location: CLLocation, animated: Bool) {
    lookUpCurrentLocation(location: location, completionHandler: {
      (placemark) in
      guard let myPosition = placemark else {
        return
      }

      self.lookUpCurrentLocation(location: CLLocation(latitude: CLLocationDegrees((self.lat as NSString).floatValue), longitude: CLLocationDegrees((self.lng as NSString).floatValue)), completionHandler: { (placemark) in
        guard let parking = placemark else {
          return
        }

        let request = MKDirections.Request()

        guard let myPositionCoordinate = myPosition.location?.coordinate,
              let parkingCoordinate = parking.location?.coordinate else {
          return
        }

        request.source = MKMapItem(placemark: MKPlacemark(coordinate: myPositionCoordinate, addressDictionary: nil))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: parkingCoordinate, addressDictionary: nil))
        request.requestsAlternateRoutes = true
        request.transportType = .automobile

        if !animated {
          let parkingAnnotation = MKPointAnnotation()
          parkingAnnotation.coordinate = parkingCoordinate

          self.myLocationAnnotation.coordinate = myPositionCoordinate

          self.mapView.addAnnotations([parkingAnnotation, self.myLocationAnnotation])
        } else {
          UIView.animate(withDuration: 1) {
            self.myLocationAnnotation.coordinate = myPositionCoordinate
          }
        }

        let directions = MKDirections(request: request)

        DispatchQueue.main.async {
          directions.calculate { [unowned self] (response, error) in
            guard let mapRoute = response?.routes.first else {
              return
            }
            self.updateMap(route: mapRoute, animated: animated)
          }
        }
      })
    })
  }

  private func lookUpCurrentLocation(location: CLLocation, completionHandler: @escaping (CLPlacemark?) -> Void) {
    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) in
      if error == nil {
        if let firstlocation = placemarks?[0] {
          completionHandler(firstlocation)
        } else {
          completionHandler(nil)
        }
      } else {
        completionHandler(nil)
      }
    })
  }
}

extension ViewController: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location: CLLocationCoordinate2D = manager.location?.coordinate else { return }

    if !isMapLoaded {
      self.mapDirection(location: CLLocation(latitude: location.latitude, longitude: location.longitude), animated: isMapLoaded)
      isMapLoaded = true
      return
    }

    self.mapDirection(location: CLLocation(latitude: location.latitude, longitude: location.longitude), animated: isMapLoaded)
  }
}

extension ViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let renderer = MKPolylineRenderer(overlay: overlay)
    renderer.strokeColor = .systemBlue
    renderer.lineWidth = 5
    return renderer
  }
}

