const it = {
  app: {
    name: 'Barber App',
  },
  auth: {
    signInWithGoogle: 'Accedi con Google',
    signOut: 'Esci',
    signedInAs: 'Accesso effettuato come',
  },
  language: {
    label: 'Lingua',
    it: 'Italiano',
    en: 'English',
  },
  errors: {
    NOT_AUTHENTICATED: 'Devi accedere per continuare.',
    PHONE_REQUIRED: 'Aggiungi il tuo numero di telefono prima di prenotare.',
    SLOT_UNAVAILABLE: 'Questo orario non è più disponibile. Scegline un altro.',
    TOO_MANY_BOOKINGS: 'Hai già il numero massimo di prenotazioni attive.',
    BOOKING_NOT_FOUND: 'Prenotazione non trovata.',
    BOOKING_NOT_ACTIVE: 'Questa prenotazione non è più attiva.',
    TOO_LATE_TO_CHANGE: 'È troppo tardi per modificare questa prenotazione.',
    generic: 'Qualcosa è andato storto. Riprova.',
  },
}

export type Translations = typeof it
export default it
