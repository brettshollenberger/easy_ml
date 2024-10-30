import "../styles/application.css"
import { createInertiaApp } from '@inertiajs/react'
import { createRoot } from 'react-dom/client'

document.addEventListener('DOMContentLoaded', () => {
  createInertiaApp({
    resolve: name => {
      console.log("Resolving page", name)
      const pages = import.meta.glob('../pages/**/*.tsx', { eager: true })
      return pages[`../${name}.tsx`]
    },
    setup({ el, App, props }) {
      console.log("Calling setup")
      createRoot(el).render(<App {...props} />)
    },
  })
}) 