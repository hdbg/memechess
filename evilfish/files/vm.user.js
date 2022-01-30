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
// @grant           GM_addElement
// @grant           GM_getValue
// @grant           GM_setValue
// @grant           GM_info
// @inject-into     auto
// @run-at          document-start
// @require         https://cdn.jsdelivr.net/npm/izitoast@1.4.0/dist/js/iziToast.min.js
// @require         https://code.jquery.com/jquery-3.6.0.min.js
// @require         https://ajax.aspnetcdn.com/ajax/jquery.ui/1.12.1/jquery-ui.min.js
// @resource        toast https://cdn.jsdelivr.net/npm/izitoast@1.4.0/dist/css/iziToast.min.css
// @resource        jui https://ajax.aspnetcdn.com/ajax/jquery.ui/1.12.1/themes/dot-luv/jquery-ui.css
// @icon            https://www.google.com/s2/favicons?domain=lichess.org
// ==/UserScript==

var window = unsafeWindow;

// CONSTS
const server_url = "http://localhost:8080";
const modes = {
    rage: "rage",
    legit: "legit"
}

// CLASSES
class Context {
    moves = [];

    state = {};

    _raw = {};

    constructor(raw, clock) {
        this._raw = raw;

        // let analysis = raw.analysis;

        raw.moves.forEach((elm, index, arr) => {
            console.log(elm);
            this.moves.push({
                uci: elm.uci,
                from: elm.uci.substring(0, 2),
                to: elm.uci.substring(2, 4)
            })
        });

        //         this.state = {
        //             depth: analysis.depth,
        //             latency: analysis.time,

        //             score: analysis.score.value,
        //             nps: analysis.nps,

        //             clock: clock,
        //             fen: raw.position.fen,
        //         };
    }

    get from() {
        return this.moves[0].from;
    }

    get to() {
        return this.moves[0].to;
    }
}

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
var Utils = {
    probability: function (prob) {
        return rand(1, 100) <= prob;
    },
    uci: function (move) {
        return { from: move.substring(0, 2), to: move.substring(2, 4) };
    },
    make_request(url, method, data, onload = null, onerror = null) {
        GM_xmlhttpRequest({
            url: server_url + url,
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

var Game = {
    config: {
        auto: true,

        mode: modes.legit
    },
    state: {
        side: "black",
        variant: "standard",
        speed: "bullet",

        clock: {
            white: 0,
            black: 0
        }
    },

    round: null,
    board: null,

    hooks: {},

    ui: {},

    boot: function (round, opts) {
        console.log(opts);

        this.round = round;
        this.board = this.round.chessground;

        this.state.side = opts.data.player.color;
        this.state.variant = opts.data.game.variant.name;
        this.state.speed = opts.data.game.speed;

        let moves_stack = [];

        if (opts.data.steps.length > 1) {
            for (let i = 1; i < opts.data.steps.length; i++) {
                moves_stack.push({san:opts.data.steps[i].san});
            }
        }

        Utils.make_request("/game/new", "POST", {
            side: this.state.side == "white",
            variant: this.state.variant,
            speed: this.state.speed,
            stack: moves_stack,
        }, (r) => {console.log(r)});

        this.hooks.apiMove = new Hook(round.socket.handlers, "move", this.move.bind(this), "after");

        // this.ui();
        //this.notify("Loaded", "green");

        window.fish = this;
    },

    notify: function (msg, color) {
        iziToast.show({
            title: "EvilFish",
            theme: "dark",
            message: msg,
            color: color,
            position: "bottomRight"
        });
    },


    move: function (from, to) {
        let ply = this.round.lastPly()
        let step = this.round.stepAt(ply);

        let time = this.time();

        console.log("Step: ", step);
        Utils.make_request("/game/push", "POST", {
            move: { san: step.san },
            ply: ply, fen: this.board.getFen(),
            white: time.white, black: time.black
        }, (r) => {
            let json = r.response;

            console.log(json);

            if (json.event == "game.engine") {
                let move = json.data.move.uci;
                


                this.send(Utils.uci(move).from, Utils.uci(move).to, 0.0);
            }
        });
    },

    send(from, to, delay) {
        this.board.selectSquare(from);

        var meta_data = {
            premove: delay == 0.0,
            ctrlKey: this.board.state.stats.ctrlKey,
            holdTime: 0.0
        }

        setTimeout(function () {
            meta_data.holdTime = this.board.state.hold.stop();
            this.board.move(from, to);
            this.round.onUserMove(from, to, meta_data);
        }.bind(this), delay);


    },

    response(ctx) {
        console.log(ctx);

        this.board.setShapes([{
            orig: ctx.from,
            dest: ctx.to,
            brush: "paleGreen"
        }]);
    },

    time() {
        return {
            white: this.round.clock != undefined ? (this.round.clock.times.white / 600) * 0.6 : 0.0,
            black:  this.round.clock != undefined ? (this.round.clock.times.black / 600) * 0.6 : 0.0
        };
    },

    ui() {
        GM_addStyle(GM_getResourceText("jui"));
        GM_addStyle(GM_getResourceText("toast"));

        var _anchor = Array.from(document.getElementsByClassName("material material-top"))[0];
        var anchor = document.createElement("div");

        {
            anchor.id = "evilfish-ui";
            anchor.className = "ui-widget-content";
            anchor.style = "width: 400px;height:400pxpadding: 2.0em;z-index:99999;margin: 10px;position: relative";
        }

        _anchor.parentNode.insertBefore(anchor, _anchor);

        $("#evilfish-ui").draggable();

        var that = this;

        function create_elm(id, type, opts, cb) {
            let elm = document.createElement(type);

            if (opts != null) {
                for (const [key, value] of Object.entries(opts)) {
                    elm[key] = value;
                }
            };
            anchor.appendChild(elm);
            that.ui[id] = elm;

            if (cb != null) {
                cb();
            }
        }

        create_elm("heading", "h1", {
            innerText: "EvilFish v." + GM_info.script.version
        });

        create_elm("auto", "button", {
            className: "ui-button ui-widget ui-corner-all",
            innerText: this.config.auto ? "Disable Auto" : "Enable Auto",
            onclick: function () {
                that.config.auto = !that.config.auto;
                that.upd();
            }
        });

    },

    upd() {

        if (this.ui.auto != undefined) {
            this.ui.auto.innerText = this.config.auto ? "Disable Auto" : "Enable Auto";
        }
    }

}


function injector() {
    let lr = window.LichessRound;
    let copy = null;
    Object.defineProperty(window, "LichessRound", {
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
};

injector();