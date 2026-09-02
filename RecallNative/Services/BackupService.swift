import Foundation
import SwiftData

struct RecallBackup: Codable {
    struct DeckRecord: Codable {
        let id: UUID; let name: String; let emoji: String; let createdAt: Date; let newLimit: Int; let newDay: String; let newStudiedToday: Int
        private enum CodingKeys: String, CodingKey { case id, name, emoji, createdAt, newLimit, newDay, newStudiedToday }
        init(id: UUID, name: String, emoji: String, createdAt: Date, newLimit: Int = 20, newDay: String, newStudiedToday: Int) { self.id=id; self.name=name; self.emoji=emoji; self.createdAt=createdAt; self.newLimit=newLimit; self.newDay=newDay; self.newStudiedToday=newStudiedToday }
        init(from decoder: Decoder) throws { let c=try decoder.container(keyedBy:CodingKeys.self); id=try c.decode(UUID.self,forKey:.id); name=try c.decode(String.self,forKey:.name); emoji=try c.decode(String.self,forKey:.emoji); createdAt=try c.decode(Date.self,forKey:.createdAt); newLimit=try c.decodeIfPresent(Int.self,forKey:.newLimit) ?? 20; newDay=try c.decode(String.self,forKey:.newDay); newStudiedToday=try c.decode(Int.self,forKey:.newStudiedToday) }
        func encode(to encoder: Encoder) throws { var c=encoder.container(keyedBy:CodingKeys.self); try c.encode(id,forKey:.id); try c.encode(name,forKey:.name); try c.encode(emoji,forKey:.emoji); try c.encode(createdAt,forKey:.createdAt); try c.encode(newLimit,forKey:.newLimit); try c.encode(newDay,forKey:.newDay); try c.encode(newStudiedToday,forKey:.newStudiedToday) }
    }
    struct CardRecord: Codable {
        let id: UUID; let question: String; let answer: String; let hint: String; let tags: String; let type: String; let typeInAnswer: Bool
        let mediaType: String?; let mediaURI: String?; let createdAt: Date; let dueAt: Date; let interval: Int; let ease: Double; let repetitions: Int
        let state: String; let step: Int; let lapses: Int; let againCount: Int; let hardCount: Int; let goodCount: Int; let easyCount: Int; let lastReviewedAt: Date?; let deckID: UUID
    }
    struct ReviewRecord: Codable { let id: UUID; let reviewedAt: Date; let rating: Int; let cardID: UUID? }
    let version: Int; let exportedAt: Date; let decks: [DeckRecord]; let cards: [CardRecord]; let reviews: [ReviewRecord]
    let history: [String: Int]
    let totalCreated: Int
    fileprivate let importedHapticsEnabled: Bool?

    private struct LegacyDeck: Decodable { let id: UUID; let name: String; let emoji: String?; let createdAt: Double?; let newLimit: Int?; let newDay: String?; let newStudiedToday: Int?; let cards: [LegacyCard]? }
    private struct LegacyCard: Decodable { let id: UUID; let front: String; let back: String; let hint: String?; let tags: String?; let type: String?; let typeIn: Bool?; let media: LegacyMedia?; let ease: Double?; let interval: Int?; let reps: Int?; let lapses: Int?; let due: Double?; let lastReviewed: Double?; let state: String?; let step: Int?; let stats: LegacyStats?; let createdAt: Double? }
    private struct LegacyMedia: Decodable { let type: String; let uri: String }
    private struct LegacyStats: Decodable { let again: Int?; let hard: Int?; let good: Int?; let easy: Int? }
    private struct LegacyMeta: Decodable { let streak: Int?; let lastStudyDate: String?; let studiedToday: Int?; let totalReviewed: Int?; let totalCreated: Int?; let entitlement: [String: Bool]?; let iCloudEnabled: Bool?; let history: [String: Int]?; let hapticsEnabled: Bool? }
    private enum RootKeys: String, CodingKey { case version, schemaVersion, exportedAt, decks, cards, reviews, meta, hapticsEnabled, history, totalCreated }

    init(version: Int, exportedAt: Date, decks: [DeckRecord], cards: [CardRecord], reviews: [ReviewRecord], history: [String:Int] = [:], totalCreated: Int = 0, hapticsEnabled: Bool? = nil) { self.version=version; self.exportedAt=exportedAt; self.decks=decks; self.cards=cards; self.reviews=reviews; self.history=history; self.totalCreated=max(0,totalCreated); self.importedHapticsEnabled=hapticsEnabled }
    init(from decoder: Decoder) throws {
        let root=try decoder.container(keyedBy:RootKeys.self)
        if let version=try root.decodeIfPresent(Int.self,forKey:.version), let exportedAt=try root.decodeIfPresent(Date.self,forKey:.exportedAt), let decks=try root.decodeIfPresent([DeckRecord].self,forKey:.decks), let cards=try root.decodeIfPresent([CardRecord].self,forKey:.cards), let reviews=try root.decodeIfPresent([ReviewRecord].self,forKey:.reviews) {
            self.init(version:version,exportedAt:exportedAt,decks:decks,cards:cards,reviews:reviews,history:try root.decodeIfPresent([String:Int].self,forKey:.history) ?? [:],totalCreated:try root.decodeIfPresent(Int.self,forKey:.totalCreated) ?? 0,hapticsEnabled:try root.decodeIfPresent(Bool.self,forKey:.hapticsEnabled)); return
        }
        let legacyDecks=try root.decode([LegacyDeck].self,forKey:.decks); let meta=try root.decodeIfPresent(LegacyMeta.self,forKey:.meta); let exportedAt=(try root.decodeIfPresent(Date.self,forKey:.exportedAt)) ?? .now
        var decks:[DeckRecord]=[]; var cards:[CardRecord]=[]
        for d in legacyDecks {
            decks.append(.init(id:d.id,name:d.name,emoji:d.emoji ?? "📚",createdAt:Self.date(d.createdAt) ?? .now,newLimit:max(0,min(1000,d.newLimit ?? 20)),newDay:d.newDay ?? "",newStudiedToday:max(0,d.newStudiedToday ?? 0)))
            for c in d.cards ?? [] {
                let mediaType=(c.media?.type == "image" || c.media?.type == "audio") ? c.media?.type : nil
                cards.append(.init(id:c.id,question:c.front,answer:c.back,hint:c.hint ?? "",tags:c.tags ?? "",type:c.type == "cloze" ? "cloze" : "basic",typeInAnswer:c.typeIn ?? false,mediaType:mediaType,mediaURI:mediaType == nil ? nil : c.media?.uri,createdAt:Self.date(c.createdAt) ?? .now,dueAt:Self.date(c.due) ?? .now,interval:max(0,c.interval ?? 0),ease:max(1.3,c.ease ?? 2.5),repetitions:max(0,c.reps ?? 0),state:["new","learning","review","relearning"].contains(c.state ?? "") ? c.state! : "new",step:max(0,c.step ?? 0),lapses:max(0,c.lapses ?? 0),againCount:max(0,c.stats?.again ?? 0),hardCount:max(0,c.stats?.hard ?? 0),goodCount:max(0,c.stats?.good ?? 0),easyCount:max(0,c.stats?.easy ?? 0),lastReviewedAt:Self.date(c.lastReviewed),deckID:d.id))
            }
        }
        self.init(version:1,exportedAt:exportedAt,decks:decks,cards:cards,reviews:[],history:meta?.history ?? [:],totalCreated:meta?.totalCreated ?? 0,hapticsEnabled:meta?.hapticsEnabled)
    }
    private static func date(_ milliseconds:Double?) -> Date? { guard let milliseconds else { return nil }; return Date(timeIntervalSince1970:milliseconds/1000) }
}

enum BackupService {
    static func makeBackup(context: ModelContext) throws -> Data {
        let decks=try context.fetch(FetchDescriptor<Deck>()).map { RecallBackup.DeckRecord(id:$0.id,name:$0.name,emoji:$0.emoji,createdAt:$0.createdAt,newLimit:$0.newLimit,newDay:$0.newDay ?? "",newStudiedToday:$0.newStudiedToday) }
        let cards=try context.fetch(FetchDescriptor<Flashcard>()).compactMap { card -> RecallBackup.CardRecord? in
            guard let deckID=card.deck?.id else { return nil }; return .init(id:card.id,question:card.question,answer:card.answer,hint:card.hint,tags:card.tags,type:card.type,typeInAnswer:card.typeInAnswer,mediaType:card.mediaType,mediaURI:card.mediaURI,createdAt:card.createdAt,dueAt:card.dueAt,interval:card.interval,ease:card.ease,repetitions:card.repetitions,state:card.state,step:card.step,lapses:card.lapses,againCount:card.againCount,hardCount:card.hardCount,goodCount:card.goodCount,easyCount:card.easyCount,lastReviewedAt:card.lastReviewedAt,deckID:deckID)
        }
        let reviews=try context.fetch(FetchDescriptor<ReviewLog>()).map { RecallBackup.ReviewRecord(id:$0.id,reviewedAt:$0.reviewedAt,rating:$0.rating,cardID:$0.card?.id) }
        let backup=RecallBackup(version:1,exportedAt:.now,decks:decks,cards:cards,reviews:reviews,history:ReviewHistoryStore.exportValues(),totalCreated:UsageMetricsStore.totalCreated,hapticsEnabled:UserDefaults.standard.object(forKey:"hapticsEnabled") as? Bool ?? true)
        let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys]; encoder.dateEncodingStrategy=.iso8601; return try encoder.encode(backup)
    }
    static func validate(_ data:Data) throws -> RecallBackup {
        let decoder=JSONDecoder(); decoder.dateDecodingStrategy=.iso8601; let backup=try decoder.decode(RecallBackup.self,from:data)
        guard backup.version == 1 else { throw BackupError.unsupportedVersion }; guard backup.decks.count <= 1000,backup.cards.count <= 100_000,backup.reviews.count <= 1_000_000 else { throw BackupError.invalidSize }; guard backup.decks.allSatisfy({ $0.newLimit >= 0 && $0.newLimit <= 1000 }) else { throw BackupError.invalidDeckLimit }
        guard Set(backup.decks.map(\.id)).count == backup.decks.count,Set(backup.cards.map(\.id)).count == backup.cards.count else { throw BackupError.duplicateIDs }; let deckIDs=Set(backup.decks.map(\.id)); guard backup.cards.allSatisfy({ deckIDs.contains($0.deckID) }) else { throw BackupError.orphanedCards }; let cardIDs=Set(backup.cards.map(\.id)); guard backup.reviews.allSatisfy({ $0.cardID == nil || cardIDs.contains($0.cardID!) }) else { throw BackupError.orphanedReviews }; guard backup.history.values.allSatisfy({ $0 >= 0 }) else { throw BackupError.invalidHistory }; guard backup.totalCreated >= 0 else { throw BackupError.invalidTotalCreated }; return backup
    }
    static func restore(_ data:Data,context:ModelContext,replaceExisting:Bool=false) throws {
        let backup=try validate(data); UsageMetricsStore.suppressNextCreationDelta()
        if !replaceExisting { let existingDeckIDs=Set(try context.fetch(FetchDescriptor<Deck>()).map(\.id)); let existingCardIDs=Set(try context.fetch(FetchDescriptor<Flashcard>()).map(\.id)); if !existingDeckIDs.isDisjoint(with:backup.decks.map(\.id)) || !existingCardIDs.isDisjoint(with:backup.cards.map(\.id)) { UsageMetricsStore.cancelSuppressedCreationDelta(); throw BackupError.idCollision } }
        else { try context.fetch(FetchDescriptor<ReviewLog>()).forEach(context.delete); try context.fetch(FetchDescriptor<Flashcard>()).forEach(context.delete); try context.fetch(FetchDescriptor<Deck>()).forEach(context.delete) }
        var deckMap:[UUID:Deck]=[:]
        for r in backup.decks { let d=Deck(name:r.name,emoji:r.emoji); d.id=r.id; d.createdAt=r.createdAt; d.newLimit=r.newLimit; d.newDay=r.newDay.isEmpty ? nil : r.newDay; d.newStudiedToday=r.newStudiedToday; context.insert(d); deckMap[r.id]=d }
        var cardMap:[UUID:Flashcard]=[:]
        for r in backup.cards { let c=Flashcard(question:r.question,answer:r.answer,hint:r.hint,tags:r.tags,deck:deckMap[r.deckID]); c.id=r.id; c.type=r.type; c.typeInAnswer=r.typeInAnswer; c.mediaType=r.mediaType; c.mediaURI=r.mediaURI; c.createdAt=r.createdAt; c.dueAt=r.dueAt; c.interval=r.interval; c.ease=r.ease; c.repetitions=r.repetitions; c.state=r.state; c.step=r.step; c.lapses=r.lapses; c.againCount=r.againCount; c.hardCount=r.hardCount; c.goodCount=r.goodCount; c.easyCount=r.easyCount; c.lastReviewedAt=r.lastReviewedAt; context.insert(c); cardMap[r.id]=c }
        for r in backup.reviews { let log=ReviewLog(rating:r.rating,card:r.cardID.flatMap { cardMap[$0] }); log.id=r.id; log.reviewedAt=r.reviewedAt; context.insert(log) }
        try context.save(); ReviewHistoryStore.replace(valuesFromStrings(backup.history)); UsageMetricsStore.replaceTotalCreated(backup.totalCreated); if let h=backup.importedHapticsEnabled { UserDefaults.standard.set(h,forKey:"hapticsEnabled") }
    }
    private static func valuesFromStrings(_ values:[String:Int]) -> [Date:Int] { values.reduce(into:[:]) { result, entry in if let date=ReviewHistoryStore.date(from:entry.key) { result[date]=entry.value } } }
    enum BackupError:LocalizedError {
        case unsupportedVersion,invalidSize,invalidDeckLimit,duplicateIDs,orphanedCards,orphanedReviews,idCollision,invalidHistory,invalidTotalCreated
        var errorDescription:String? { switch self { case .unsupportedVersion:return "This backup was created by an unsupported Recall version."; case .invalidSize:return "This backup is too large to import safely."; case .invalidDeckLimit:return "This backup contains an invalid daily new-card limit."; case .duplicateIDs:return "This backup contains duplicate records."; case .orphanedCards:return "This backup contains cards without a valid deck."; case .orphanedReviews:return "This backup contains reviews without a valid card."; case .idCollision:return "This backup contains records that already exist in your library. Choose replace-all restore instead."; case .invalidHistory:return "This backup contains invalid review history."; case .invalidTotalCreated:return "This backup contains invalid creation history." } }
    }
}
