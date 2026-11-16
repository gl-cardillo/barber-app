import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import en from "./locales/en";
import it from "./locales/it";

export const SUPPORTED_LANGUAGES = ["it", "en"] as const;
export type Language = (typeof SUPPORTED_LANGUAGES)[number];

const STORAGE_KEY = "language";

function isSupported(value: unknown): value is Language {
  return SUPPORTED_LANGUAGES.includes(value as Language);
}

const envDefault = import.meta.env.VITE_DEFAULT_LANGUAGE;
export const DEFAULT_LANGUAGE: Language = isSupported(envDefault)
  ? envDefault
  : "it";

function readStoredLanguage(): Language | null {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    return isSupported(stored) ? stored : null;
  } catch {
    return null;
  }
}

export function setLanguage(language: Language) {
  try {
    localStorage.setItem(STORAGE_KEY, language);
  } catch {}
  return i18n.changeLanguage(language);
}

i18n.on("languageChanged", (language) => {
  document.documentElement.lang = language;
});

i18n.use(initReactI18next).init({
  resources: {
    it: { translation: it },
    en: { translation: en },
  },
  lng: readStoredLanguage() ?? DEFAULT_LANGUAGE,
  fallbackLng: DEFAULT_LANGUAGE,
  interpolation: { escapeValue: false },
});

export default i18n;
