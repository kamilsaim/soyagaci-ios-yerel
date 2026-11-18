import Foundation

/// Kişi formunda toplanmış değerler (kullanıcının yazdığı ham metinler; normalleştirmeyi `savePerson` yapar).
public struct KisiFormu: Equatable {
    /// Düzenlenen kişinin kimliği; yeni kişide nil.
    public var id: String?
    public var firstName: String
    public var lastName: String
    public var gender: String
    public var birthDate: String
    public var birthPlace: String
    public var deathDate: String
    public var deathPlace: String
    public var deceased: Bool
    public var occupation: String
    public var maidenName: String
    public var notes: String
    public var mother: String?
    public var father: String?
    public var photo: String?
    public var gallery: [String]
    public var spouses: [EsBag]
    public var children: [String]

    public init(id: String? = nil, firstName: String = "", lastName: String = "", gender: String = "M",
                birthDate: String = "", birthPlace: String = "", deathDate: String = "", deathPlace: String = "",
                deceased: Bool = false, occupation: String = "", maidenName: String = "", notes: String = "",
                mother: String? = nil, father: String? = nil, photo: String? = nil, gallery: [String] = [],
                spouses: [EsBag] = [], children: [String] = []) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.gender = gender
        self.birthDate = birthDate
        self.birthPlace = birthPlace
        self.deathDate = deathDate
        self.deathPlace = deathPlace
        self.deceased = deceased
        self.occupation = occupation
        self.maidenName = maidenName
        self.notes = notes
        self.mother = mother
        self.father = father
        self.photo = photo
        self.gallery = gallery
        self.spouses = spouses
        self.children = children
    }
}

/// `savePerson` sonucu. `hata` metni web `toast` metniyle aynıdır.
public enum KaydetSonuc: Equatable {
    case tamam(id: String, eskiFotolar: [String])
    case hata(String)
}
