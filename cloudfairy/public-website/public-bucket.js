const { readFileSync } = require('fs');
const { join: pathJoin } = require('path');

/**
 * @typedef {Record<string, any>} EnvConfig
 * @property {string} [cloud_provider]
 * @property {string} environment_name
 * @property {string} project_name
 */

/**
 * @typedef LocalConfig
 * @property {string} bucketName
 * @property {string} indexPage
 * @property {string} errorPage
 */

/**
 * 
 * @param {LocalConfig} localConfig 
 * @param {EnvConfig} envConfig 
 */


module.exports = (localConfig, envConfig) => {
  const { cloud_provider } = envConfig;

  if (cloud_provider === 'gcp') {
    const content = readFileSync(pathJoin(__dirname, 'public-bucket.gcp.tf')).toString('utf-8');
    return {
      metadata: {},
      tfModules: {
        'main.tf': content
      }
    };
  }
};

let r = module.exports({}, {});