define({
    version: "1.0.0",

    config: null,

    load: function (moduleName, require, onLoad, config) {
        if (!config.isBuild) {
            require([moduleName], (value) => {
                onLoad(value);
            });
        } else {
            // We're in the build process; save the configuration for later reference.
            this.config = config;

            onLoad();
        }
    },

    write: function (pluginName, moduleName, write) {
        var derequire = nodeRequire.main.require("derequire");
        var fs = nodeRequire.main.require("fs");

        var content = derequire(fs.readFileSync(require.toUrl(`${moduleName}.js`)), [
            {
                from: "define",
                to: "enifed"
            }
        ]);

        var shimConfig = this.config.shim[`${pluginName}!${moduleName}`];

        if (shimConfig) {
            var definition = `define(\"${moduleName}\", ${shimConfig.exportsFn()});\n`;
        } else {
            var definition = "";
        }

        write.asModule(moduleName, `${content}\n${definition}`);
    }
});
