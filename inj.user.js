// ==UserScript==
// @name            EvilFish
// @version         1.0
// @match           https://lichess.org/*
// @exclude-match   https://lichess.org/tv/*
// @connect         localhost
// @grant           unsafeWindow
// @grant           GM_xmlhttpRequest
// @grant           GM_addStyle
// @grant           GM_getResourceText
// @inject-into     auto
// @run-at          document-start
// @icon            https://www.google.com/s2/favicons?domain=lichess.org
// @require         https://asbros.github.io/popup.js/popup.js
// ==/UserScript==


// CONSTS
const consts = {
    server_url: "http://localhost:4323"
}

// CLASSES


class Hook {
    original = null;
    reference = null;

    callback = null;

    mode = "before";

    constructor(obj, key, callback, mode = "before") {
        this.reference = obj;
        this.original = obj[key];
        this.callback = callback;
        this.mode = mode;

        obj[key] = this.hooker.bind(this);
    }

    hooker(...args) {
        if (this.mode == "before") {
            this.callback(...args);
            return this.call(args);

        } else if (this.mode == "after") {
            let r = this.call(args);
            this.callback(...args);

            return r;
        }
    }

    call(args) {
        return Reflect.apply(this.original, this.reference, args);
    }
}

// MAIN LOGIC
let Utils = {
    uci: function (move) {
        return {from: move.substring(0, 2), to: move.substring(2, 4)};
    },
    make_request(url, method, data, onload = null, onerror = null) {
        GM_xmlhttpRequest({
            url: consts.server_url + url,
            method: method,
            data: JSON.stringify(data),
            responseType: "json",
            headers: {
                "content-type": "application/json",
                "accept": "application/json"
            },
            onload: onload,
            onerror: onerror
        });
    }
}

let Game = {
    hooks: {},

    boot: function (ctrl, opts) {
        var loader = as.loader();
        loader.show({
            timer: 10000
        });


        console.log(ctrl);
        console.log(opts);

        this.ctrl = ctrl;
        this.opts = opts.data;

        let init_game_data = {
            id: this.opts.game.id,
            variant: this.opts.game.variant.name,
            player_side: this.opts.game.player === "white",

            history: []
        }

        if (this.opts.clock !== undefined) {
            if (this.opts.clock.increment !== undefined) {
                init_game_data.inc = this.opts.clock.increment
            }
            if (this.opts.clock.white !== undefined) {
                init_game_data.white_clock = this.opts.clock.white + 0.0;
                init_game_data.black_clock = this.opts.clock.black + 0.0;
            }
        }

        if (opts.data.steps.length > 1) {
            for (let i = 1; i < opts.data.steps.length; i++) {
                init_game_data.history.push(opts.data.steps[i].uci);
            }
        }

        if (this.opts.crazyhouse !== undefined) {
            let pockets = this.opts.crazyhouse.pockets;

            init_game_data.white_pocket = pockets[0];
            init_game_data.black_pocket = pockets[1];
        }


        Utils.make_request("/new", "POST", init_game_data, (r) => {
            loader.hide();
        }, (r) => {
            loader.hide();
            as.toast({
                type: "error",
                title: "Can't contact server",
                timer: 2000
            });

            return;
        })

        this.hooks.apiMove = new Hook(ctrl, "apiMove", this.move_hook.bind(this), "after");
        this.hooks.apiMove = new Hook(ctrl.socket.handlers, "drop", this.move_hook.bind(this), "after");
    },

    move_hook: function (from, to) {
        let ply = this.ctrl.lastPly()
        let step = this.ctrl.stepAt(ply);

        let time = this.time();

        console.log(ply, step);


        let game_move_data = {
            move: step.uci
        }
    },

    time: function () {
        if (this.ctrl.clock === undefined) {
            return null;
        }

        function proc(time) {
            return (time / 1000)
        }

        return {
            white_clock: proc(this.ctrl.clock.times.white),
            black_clock: proc(this.ctrl.clock.times.black)
        };
    }
}


function injector() {
    let lr = unsafeWindow.LichessRound;
    let copy = null;
    Object.defineProperty(unsafeWindow, "LichessRound", {
        get: function () {
            return lr;
        },
        set: function (obj) {
            lr = obj;
            copy = lr.app;
            lr.app = function (opts) {
                var response = copy(opts);
                Game.boot(response.moveOn.ctrl, opts);

                return response;
            }
        }
    });
}

injector();