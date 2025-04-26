/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      backgroundColor: {
        warning: '#f0ad4e',
        success: '#5cb85c',
        error: '#d9534f',
        info: '#5bc0de'
      },
      border: {
        grey: '#e8e8e8'
      },
      outline: {
        grey: '#e8e8e8'
      },
      divide: {
        grey: '#e8e8e8'
      },
      colors: {
        brand: {
          darkBlue: '#0A2647',
          bluePrimary: '#144272',
          blueSecondary: '#205295',
          blueLight: '#2C74B3',
          lightBlue: '#E0ECFF', // light version of 0A2647
          lightPrimary: '#D0E0FF', // light version of 144272
          lightSecondary: '#C0D4FF', // light version of 205295
          lightHighlight: '#B0C8FF', // light version of 2C74B3
          hover: {
            darkBlue: '#09384D', // A bit lighter/darker for hover effect
            bluePrimary: '#123D60',
            blueSecondary: '#1A5280',
            lightBlue: '#C0D9FF'
          },
          active: {
            darkBlue: '#072340', // A darker tone for active state
            bluePrimary: '#112D46'
          }
        }
      }
    }
  },
  plugins: []
};
