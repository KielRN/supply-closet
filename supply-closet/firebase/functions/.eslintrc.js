module.exports = {
  env: {
    es2022: true,
    node: true,
  },
  extends: ["eslint:recommended"],
  parserOptions: {
    ecmaVersion: 2022,
  },
  rules: {
    "no-constant-condition": ["error", {"checkLoops": false}],
    "no-console": "off",
  },
};
