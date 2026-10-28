/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
    './hooks/**/*.{js,ts,jsx,tsx}',
  ],
  darkMode: 'class', // enable class strategy
  theme: {
    extend: {
      colors: {
        // Apple‑inspired glass palette
        background: 'hsla(var(--bg-hsl), <alpha-value>)',
        surface: 'hsla(var(--surface-hsl), <alpha-value>)',
        accent: {
          DEFAULT: '#0066FF', // restrained accent
          dark: '#3399FF',
        },
        neutral: {
          100: '#F5F5F5',
          200: '#E5E5E5',
          300: '#D4D4D4',
          400: '#A3A3A3',
          500: '#737373',
          600: '#525252',
          700: '#404040',
          800: '#262626',
          900: '#171717',
        },
      },
      backdropBlur: {
        xs: '2px',
        sm: '4px',
        md: '8px',
        lg: '12px',
        xl: '16px',
      },
      borderRadius: {
        lg: '0.75rem',
        md: '0.5rem',
      },
    },
  },
  plugins: [require('@tailwindcss/forms'), require('@tailwindcss/typography')],
};
