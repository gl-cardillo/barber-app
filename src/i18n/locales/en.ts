import type { Translations } from './it'

const en: Translations = {
  app: {
    name: 'Barber App',
  },
  auth: {
    signInWithGoogle: 'Sign in with Google',
    signOut: 'Sign out',
    signedInAs: 'Signed in as',
  },
  language: {
    label: 'Language',
    it: 'Italiano',
    en: 'English',
  },
  errors: {
    NOT_AUTHENTICATED: 'You need to sign in to continue.',
    PHONE_REQUIRED: 'Please add your phone number before booking.',
    SLOT_UNAVAILABLE: 'This time is no longer available. Please pick another.',
    TOO_MANY_BOOKINGS: 'You already have the maximum number of upcoming bookings.',
    BOOKING_NOT_FOUND: 'Booking not found.',
    BOOKING_NOT_ACTIVE: 'This booking is no longer active.',
    TOO_LATE_TO_CHANGE: 'It is too late to change this booking.',
    generic: 'Something went wrong. Please try again.',
  },
}

export default en
