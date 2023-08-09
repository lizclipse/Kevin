//
//  AppleMaps.swift
//
//
//  Created by Elizabeth (lizclipse) on 10/08/2023.
//

import Foundation
import Logging

// TODO: fix everything
final class MapsClient {
  private let authToken: String
  private var accessToken: String? = nil

  private let logger = Logger(label: "MapsClient", level: .debug)

  init(authToken: String) {
    self.authToken = authToken
  }

  func geocode(
    _ query: String,
    limitToCountries: [String]? = nil,
    lang: String? = nil,
    searchLocation: MapsLocation? = nil,
    searchRegion: MapsMapRegion? = nil,
    userLocation: MapsLocation? = nil
  ) async throws -> [MapsPlace] {
    var query = [
      URLQueryItem(name: "q", value: query)
    ]

    if let limitToCountries = limitToCountries, !limitToCountries.isEmpty {
      query.append(
        URLQueryItem(
          name: "limitToCountries", value: limitToCountries.joined(separator: ",")))
    }

    if let lang = lang {
      query.append(URLQueryItem(name: "lang", value: lang))
    }

    if let searchLocation = searchLocation {
      query.append(
        URLQueryItem(name: "searchLocation", value: String(mapsLocation: searchLocation)))
    }

    if let searchRegion = searchRegion {
      query.append(
        URLQueryItem(name: "searchRegion", value: String(mapsMapRegion: searchRegion)))
    }

    if let userLocation = userLocation {
      query.append(
        URLQueryItem(name: "userLocation", value: String(mapsLocation: userLocation)))
    }

    let res: MapsPlaceResults = try await getReq(path: "geocode", query: query)
    return res.results
  }
}

private let baseUrl = "https://maps-api.apple.com/v1"
extension MapsClient {
  private func getReq<T: Codable>(path: String, query: [URLQueryItem] = []) async throws -> T {
    let token = try await getToken()
    return try await getReq(path: path, query: query, token: token)
  }

  private func getReq<T: Codable>(path: String, query: [URLQueryItem] = [], token: String)
    async throws -> T
  {
    var urlBuilder = URLComponents(string: "\(baseUrl)/\(path)")!
    urlBuilder.queryItems = query

    var req = URLRequest(url: urlBuilder.url!)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")

    let url = "\(baseUrl)/\(path)"
    logger.trace("making request to \(url)")
    let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func getToken() async throws -> String {
    if let token = accessToken {
      return token
    }

    logger.debug("updating access token")
    let res: MapsTokenResponse = try await getReq(path: "token", token: authToken)
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(res.expiresInSeconds)) {
      @Sendable in
      // self.accessToken = nil
      // self.logger.debug("cleared access token")
    }
    accessToken = res.accessToken
    return res.accessToken
  }
}

struct MapsTokenResponse: Codable {
  let accessToken: String
  /// Time in seconds until it expires
  let expiresInSeconds: Int

  init(accessToken: String, expiresInSeconds: Int) {
    self.accessToken = accessToken
    self.expiresInSeconds = expiresInSeconds
  }
}

/// An object that contains information you can use to suggest addresses and further refine search results.
struct MapsAutocompleteResult: Codable {
  /// The relative URI to the search endpoint to use to fetch more details pertaining to the result.
  ///
  /// If available, the framework encodes opaque data about the autocomplete result in the completion URL’s metadata parameter.
  /// If clients need to fetch the search result in a certain language, they’re responsible for specifying the lang parameter in the request.
  let completionUrl: String
  /// A JSON string array to use to create a long form of display text for the completion result.
  let displayLines: [String]
  /// A Location object that specifies the location for the request in terms of its latitude and longitude.
  let location: MapsLocation
  /// A StructuredAddress object that describes the detailed address components of a place.
  let structuredAddress: MapsStructuredAddress

  init(
    completionUrl: String, displayLines: [String], location: MapsLocation,
    structuredAddress: MapsStructuredAddress
  ) {
    self.completionUrl = completionUrl
    self.displayLines = displayLines
    self.location = location
    self.structuredAddress = structuredAddress
  }
}

/// An object that describes the directions from a starting location to a destination in terms routes, steps, and a series of waypoints.
struct MapsDirectionsResponse: Codable {
  /// A Place object that describes the destination.
  let destination: MapsPlace
  /// A Place object that describes the destination.
  let origin: MapsPlace
  /// An array of routes. Each route references steps based on indexes into the steps array.
  let routes: [Route]
  /// An array of step paths across all steps across all routes.
  ///
  /// Each step path is a single polyline represented as an array of points.
  /// You reference the step paths by index into the array.
  let stepPaths: [MapsLocation]
  /// An array of all steps across all routes.
  ///
  /// You reference the route steps by index into this array.
  /// Each step in turn references its path based on indexes into the stepPaths array.
  let steps: [Step]

  init(
    destination: MapsPlace, origin: MapsPlace, routes: [Route], stepPaths: [MapsLocation],
    steps: [Step]
  ) {
    self.destination = destination
    self.origin = origin
    self.routes = routes
    self.stepPaths = stepPaths
    self.steps = steps
  }

  /// An object that represent the components of a single route.
  struct Route: Codable {
    /// Total distance that the route covers, in meters.
    let distanceMeters: Int
    /// The estimated time to traverse this route in seconds.
    ///
    /// If you’ve specified a departureDate or arrivalDate, then the estimated time includes traffic conditions
    /// assuming user departs or arrives at that time. If you set neither departureDate or arrivalDate,
    /// then estimated time represents current traffic conditions assuming user departs “now” from the point of origin.
    let durationSeconds: Int
    /// When true, this route has tolls; if false, this route has no tolls.
    let hasTolls: Bool
    /// The route name that you can use for display purposes.
    let name: String
    /// An array of integer values that you can use to determine the number steps along this route.
    ///
    /// Each value in the array corresponds to an index into the steps array.
    let stepIndexes: [Int]
    /// A string that represents the mode of transportation the service used to estimate the arrival time.
    ///
    /// Same as the input query param transportType or Automobile if the input query didn’t specify a transportation type.
    let transportType: TransportType

    init(
      distanceMeters: Int, durationSeconds: Int, hasTolls: Bool, name: String,
      stepIndexes: [Int], transportType: TransportType
    ) {
      self.distanceMeters = distanceMeters
      self.durationSeconds = durationSeconds
      self.hasTolls = hasTolls
      self.name = name
      self.stepIndexes = stepIndexes
      self.transportType = transportType
    }
  }

  /// An object that represents a step along a route.
  struct Step: Codable {
    /// Total distance covered by the step, in meters.
    let distanceMeters: Int
    /// The estimated time to traverse this step, in seconds.
    let durationSeconds: Int
    /// The localized instruction string for this step that you can use for display purposes.
    ///
    /// You can specify the language to receive the response in using the lang parameter.
    let instructions: String
    /// A pointer to this step’s path. The pointer is in the form of an index into the stepPaths array contained in a Route.
    ///
    /// Step paths are self-contained which implies that the last point of a previous step path along a route is the same
    /// as the first point of the next step path. Clients are responsible for avoiding duplication when rendering the point.
    let stepPathIndex: Int
    /// A string indicating the transport type for this step if it’s different from the transportType in the route.
    let transportType: TransportType?

    init(
      distanceMeters: Int, durationSeconds: Int, instructions: String, stepPathIndex: Int,
      transportType: TransportType?
    ) {
      self.distanceMeters = distanceMeters
      self.durationSeconds = durationSeconds
      self.instructions = instructions
      self.stepPathIndex = stepPathIndex
      self.transportType = transportType
    }
  }

  enum TransportType: Codable {
    case automobile
    case walking

    enum CodingKeys: String, CodingKey {
      case automobile = "Automobile"
      case walking = "Walking"
    }
  }
}

/// An object that contains an array of places.
struct MapsPlaceResults: Codable {
  /// An array of one or more Place objects.
  let results: [MapsPlace]

  init(results: [MapsPlace]) {
    self.results = results
  }
}

/// An object that describes a place in terms of a variety of spatial, administrative, and qualitative properties.
struct MapsPlace: Codable {
  /// The country or region of the place.
  let country: String
  /// The 2-letter country code of the place.
  let countryCode: String
  /// The geographic region associated with the place.
  ///
  /// This is a rectangular region on a map expressed as south-west and north-east points.
  /// Specifically south latitude, west longitude, north latitude, and east longitude.
  let displayMapRegion: MapsMapRegion
  /// The address of the place, formatted using its conventions of its country or region.
  let formattedAddressLines: [String]
  /// A place name that you can use for display purposes.
  let name: String
  /// The latitude and longitude of this place.
  let coordinate: MapsLocation
  /// A StructuredAddress object that describes details of the place’s address.
  let structuredAddress: MapsStructuredAddress

  init(
    country: String, countryCode: String, displayMapRegion: MapsMapRegion,
    formattedAddressLines: [String], name: String, coordinate: MapsLocation,
    structuredAddress: MapsStructuredAddress
  ) {
    self.country = country
    self.countryCode = countryCode
    self.displayMapRegion = displayMapRegion
    self.formattedAddressLines = formattedAddressLines
    self.name = name
    self.coordinate = coordinate
    self.structuredAddress = structuredAddress
  }
}

/// An object that describes a map region in terms of its upper-right and lower-left corners as a pair of geographic points.
struct MapsMapRegion: Codable {
  let eastLongitude: Double
  let northLatitude: Double
  let southLatitude: Double
  let westLongitude: Double

  init(eastLongitude: Double, northLatitude: Double, southLatitude: Double, westLongitude: Double) {
    self.eastLongitude = eastLongitude
    self.northLatitude = northLatitude
    self.southLatitude = southLatitude
    self.westLongitude = westLongitude
  }
}

extension String {
  init(mapsMapRegion: MapsMapRegion) {
    self =
      "\(mapsMapRegion.northLatitude),\(mapsMapRegion.eastLongitude),\(mapsMapRegion.southLatitude),\(mapsMapRegion.westLongitude)"
  }
}

/// An object that describes a location in terms of its longitude and latitude.
struct MapsLocation: Codable {
  let latitude: Double
  let longitude: Double

  init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

extension String {
  init(mapsLocation: MapsLocation) {
    self = "\(mapsLocation.latitude),\(mapsLocation.longitude)"
  }
}

/// An object that describes the detailed address components of a place.
struct MapsStructuredAddress: Codable {
  /// The state or province of the place.
  let administrativeArea: String
  /// The short code for the state or area.
  let administrativeAreaCode: String
  /// Common names of the area in which the place resides.
  let areasOfInterest: [String]
  /// Common names for the local area or neighborhood of the place.
  let dependentLocalities: [String]
  /// A combination of thoroughfare and subthoroughfare.
  let fullThoroughfare: String
  /// The city of the place.
  let locality: String
  /// The postal code of the place.
  let postCode: String
  /// The name of the area within the locality.
  let subLocality: String
  /// The number on the street at the place.
  let subThoroughfare: String
  /// The street name at the place.
  let thoroughfare: String

  init(
    administrativeArea: String, administrativeAreaCode: String, areasOfInterest: [String],
    dependentLocalities: [String], fullThoroughfare: String, locality: String, postCode: String,
    subLocality: String, subThoroughfare: String, thoroughfare: String
  ) {
    self.administrativeArea = administrativeArea
    self.administrativeAreaCode = administrativeAreaCode
    self.areasOfInterest = areasOfInterest
    self.dependentLocalities = dependentLocalities
    self.fullThoroughfare = fullThoroughfare
    self.locality = locality
    self.postCode = postCode
    self.subLocality = subLocality
    self.subThoroughfare = subThoroughfare
    self.thoroughfare = thoroughfare
  }
}
