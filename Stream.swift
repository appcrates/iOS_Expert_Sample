

import Foundation
import ObjectMapper
import SwiftDate

class Stream: Mappable, DataIdentifieable {
    
    var id: String?
    var title: String?
    var startDate: Date?
    var endDate: Date?
    var visibleDate: Date?
    var venueId: String?
    var images: [ImageData]?
    var artistId: String?
    var description: String?
    var ticketUrl: URL?
    var genres: [String] = []
    
    var isBoxOffice: Bool = false
    var isLiveEventType: Bool = true
    
    var hasTicketUrl: Bool {
        get {
            return ticketUrl != nil
        }
    }
    
    required init?(map: Map) {
        
    }
    
    func mapping(map: Map) {
        id          <- map["streamId"]
        title       <- map["title"]
        genres      <- map["genres"]
        venueId     <- map["venueId"]
        images      <- map["images"]
        artistId    <- map["artistId"]
        description <- map["description"]
        ticketUrl   <- (map["ticketUrl"], UrlTransform())
        
        startDate   <- (map["startDate"], DateFormatterTransform(dateFormatter: DateFormatterVendor.iso8601Formatter))
        endDate     <- (map["endDate"], DateFormatterTransform(dateFormatter: DateFormatterVendor.iso8601Formatter))
        visibleDate <- (map["visibleDate"], DateFormatterTransform(dateFormatter: DateFormatterVendor.iso8601Formatter))

        isBoxOffice <- map["isBoxOffice"]
        isLiveEventType <- map["isLive"]
    }
    
    // MARK: DataIdentifieable
    
    func identifieableIdentifier() -> String? {
        return self.id
    }
}



extension Stream: MediaItem {
    
    // MARK: Metadata
    
    func metadataIdentifier() -> String? {
        return self.id
    }
    
    func metadataTitle() -> String? {
        return self.title
    }
    
    func metadataVenueId() -> String? {
        return self.venueId
    }
    
    func metadataArtistId() -> String? {
        return self.artistId
    }
    
    func metadataArtworkUrl() -> String? {
        return self.images?.first?.url
    }
}

extension Stream {
    
    var isLive: Bool {
        guard let startDate = self.startDate, let endDate = self.endDate else {
            return false
        }
        
        let currentDate = Date()
        return currentDate >= startDate && currentDate <= endDate
    }
    
    func isLiveBetween(startDate: Date, endDate: Date) -> Bool {
        guard let eventStartDate = self.startDate, let eventEndDate = self.endDate else {
            return false
        }
        
        return startDate <= eventEndDate && eventStartDate < endDate
    }
}
