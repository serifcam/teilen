module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": "off",
    "prefer-arrow-callback": "off",
    "quotes": "off",
    "max-len": "off",
    "indent": "off",
    "no-unused-vars": "off",
    "comma-dangle": "off",
    "operator-linebreak": "off"
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
