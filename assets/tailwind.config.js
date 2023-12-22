// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/demux_web.ex",
    "../lib/demux_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        bgdark: "#191919",
        white2: "#EAECF0",
        "winter-sky": {
          50: "#fff0f4",
          100: "#ffe2ea",
          200: "#ffcada",
          300: "#ff9fbc",
          400: "#ff699a",
          500: "#ff206e",
          600: "#ed1168",
          700: "#c80859",
          800: "#a80951",
          900: "#8f0c4b",
        },
        turquoise: {
          50: "#f0fdfa",
          100: "#cbfcf3",
          200: "#97f8e8",
          300: "#41ead4",
          400: "#2ad7c7",
          500: "#11bbae",
          600: "#0a978e",
          700: "#0d7873",
          800: "#0f605c",
          900: "#124f4d",
        },
        "lemon-glacier": {
          50: "#fbfee8",
          100: "#f7ffc2",
          200: "#f2ff87",
          300: "#f2ff43",
          400: "#fbff12",
          500: "#efe903",
          600: "#ceb900",
          700: "#a48604",
          800: "#88680b",
          900: "#735510",
        },
      },
      bleedColor: {
        turquoise: {
          50: "#f0fdfa",
          100: "#cbfcf3",
          200: "#97f8e8",
          300: "#41ead4",
          400: "#2ad7c7",
          500: "#11bbae",
          600: "#0a978e",
          700: "#0d7873",
          800: "#0f605c",
          900: "#124f4d",
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
    plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "./vendor/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
        })
      })
      matchComponents({
        "hero": ({ name, fullPath }) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": theme("spacing.5"),
            "height": theme("spacing.5")
          }
        }
      }, { values })
    })
  ]
}
