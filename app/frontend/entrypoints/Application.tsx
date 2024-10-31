import "../styles/application.css"
import { createInertiaApp } from '@inertiajs/react'
import { createRoot } from 'react-dom/client'
import Layout from '../layouts/Layout';

document.addEventListener('DOMContentLoaded', () => {
  createInertiaApp({
    resolve: name => {
      console.log(`resolving component ${name}`)
      const pages = import.meta.glob('../pages/**/*.tsx', { eager: true })
      let page = pages[`../${name}.tsx`];
      page.default.layout = page.default.layout || (page => <Layout children={page} />)
      return page;
    },
    setup({ el, App, props }) {
      createRoot(el).render(
        <App {...props} />
      )
    },
  })
}) 