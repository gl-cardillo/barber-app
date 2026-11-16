import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { useTranslation } from 'react-i18next'
import { supabase } from './lib/supabase'
import { LanguageSwitcher } from './components/LanguageSwitcher'


function App() {
  const { t } = useTranslation()
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })
    return () => data.subscription.unsubscribe()
  }, [])

  const signIn = () =>
    supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin },
    })

  const signOut = () => supabase.auth.signOut()

  if (loading) return null

  return (
    <main className="min-h-screen flex items-center justify-center bg-neutral-100 p-4">
      <div className="absolute top-4 right-4">
        <LanguageSwitcher />
      </div>
      <div className="w-full max-w-sm rounded-2xl bg-white p-8 shadow text-center space-y-4">
        <h1 className="text-2xl font-semibold">{t('app.name')}</h1>
        {session ? (
          <>
            <p className="text-neutral-600">
              {t('auth.signedInAs')} <strong>{session.user.email}</strong>
            </p>
            <button
              onClick={signOut}
              className="w-full rounded-lg border border-neutral-300 px-4 py-2 hover:bg-neutral-50"
            >
              {t('auth.signOut')}
            </button>
          </>
        ) : (
          <button
            onClick={signIn}
            className="w-full rounded-lg bg-neutral-900 px-4 py-2 text-white hover:bg-neutral-700"
          >
            {t('auth.signInWithGoogle')}
          </button>
        )}
      </div>
    </main>
  )
}

export default App
