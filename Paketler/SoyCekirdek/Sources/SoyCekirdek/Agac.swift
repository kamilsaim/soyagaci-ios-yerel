import Foundation

/// Web `people` + `nextId` durumu. Kisiler ham JSON olarak tutulur: bilinmeyen alanlar kaybolmaz.
public struct Agac: Equatable {
    public var people: Nesne
    public var nextId: Int

    public init(people: Nesne = Nesne(), nextId: Int = 1) {
        self.people = people
        self.nextId = nextId
    }

    /// `people[id]` (yalnızca nesne olan kayıtlar kişi sayılır).
    public func kisi(_ id: String) -> Kisi? {
        if case .object(let o)? = people[id] { return Kisi(o) }
        return nil
    }
}

/// Eş bağlantısı: web `{id, status}` (status: married | divorced | widowed | partner).
public struct EsBag: Equatable {
    public var id: String
    public var status: String

    public init(id: String, status: String) {
        self.id = id
        self.status = status
    }
}

/// Bir kişinin ham JSON'u üzerinde web alan adlarıyla okuma görünümü.
public struct Kisi: Equatable {
    public var ham: Nesne

    public init(_ ham: Nesne) {
        self.ham = ham
    }

    func metinAlani(_ anahtar: String) -> String {
        return ham[anahtar]?.jsMetinVeyaBos ?? ""
    }

    func bagAlani(_ anahtar: String) -> String? {
        guard let j = ham[anahtar], j.dogru else { return nil }
        return j.jsMetin
    }

    public var id: String { return metinAlani("id") }
    public var firstName: String { return metinAlani("firstName") }
    public var lastName: String { return metinAlani("lastName") }
    public var maidenName: String { return metinAlani("maidenName") }
    public var gender: String { return metinAlani("gender") }
    public var birthDate: String { return metinAlani("birthDate") }
    public var birthPlace: String { return metinAlani("birthPlace") }
    public var deathDate: String { return metinAlani("deathDate") }
    public var deathPlace: String { return metinAlani("deathPlace") }
    public var deceased: Bool { return ham["deceased"]?.dogru ?? false }
    public var occupation: String { return metinAlani("occupation") }
    public var maritalStatus: String { return metinAlani("maritalStatus") }
    public var notes: String { return metinAlani("notes") }
    public var photo: String? { return bagAlani("photo") }
    public var gallery: [String] {
        guard let d = ham["gallery"]?.dizi else { return [] }
        return d.map { $0.jsMetinVeyaBos }
    }
    public var mother: String? { return bagAlani("mother") }
    public var father: String? { return bagAlani("father") }
    public var spouse: String? { return bagAlani("spouse") }
    public var spouses: [EsBag] {
        guard let d = ham["spouses"]?.dizi else { return [] }
        var cikti: [EsBag] = []
        for s in d {
            guard let kimlik = s["id"], kimlik.dogru else { continue }
            cikti.append(EsBag(id: kimlik.jsMetin, status: s["status"]?.jsMetinVeyaBos ?? ""))
        }
        return cikti
    }
    public var children: [String] {
        guard let d = ham["children"]?.dizi else { return [] }
        return d.map { $0.jsMetinVeyaBos }
    }
}
