import { useTranslation } from 'react-i18next'
import { SUPPORTED_LANGUAGES, setLanguage } from '../i18n'

export function LanguageSwitcher() {
  const { t, i18n } = useTranslation()

  return (
    <div role="group" aria-label={t('language.label')} className="inline-flex rounded-lg border border-neutral-300 p-0.5 text-sm">
      {SUPPORTED_LANGUAGES.map((language) => {
        const active = i18n.resolvedLanguage === language
        return (
          <button
            key={language}
            type="button"
            onClick={() => setLanguage(language)}
            aria-pressed={active}
            title={t(`language.${language}`)}
            className={`rounded-md px-2.5 py-1 font-medium uppercase ${
              active ? 'bg-neutral-900 text-white' : 'text-neutral-600 hover:bg-neutral-100'
            }`}
          >
            {language}
          </button>
        )
      })}
    </div>
  )
}
