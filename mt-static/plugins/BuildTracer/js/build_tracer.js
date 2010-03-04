function select_info(sel) {
    if (sel == 'info-output') {
        var hide = getByID('info-vars');
        DOM.addClassName(getByID('button-info-output'), 'control-switch-selected');
        DOM.removeClassName(getByID('button-info-var'), 'control-switch-selected');
    }
    else {
        var hide = getByID('info-output');
        DOM.removeClassName(getByID('button-info-output'), 'control-switch-selected');
        DOM.addClassName(getByID('button-info-var'), 'control-switch-selected');
    }
    var show = getByID(sel);
    DOM.addClassName(hide, 'hidden');
    DOM.removeClassName(show, 'hidden');
    
}

var HIDE_CONTROL = 0;
function toggle_control_display(){
    var c = document.getElementById('tracer-control');
    var cc = document.getElementById('control-wrapper');
    if (HIDE_CONTROL) {
        c.style.width = '100%';
        c.style.height = '120px';
        cc.style.display = 'block';
        document.getElementById('control-toggle').style.backgroundPosition = "0 0";
    }
    else {
        c.style.width = '16px';
        c.style.height = '16px';
        cc.style.display = 'none';
        document.getElementById('control-toggle').style.backgroundPosition = "-16px 0";
    }
    HIDE_CONTROL = !HIDE_CONTROL;
}

function show_tag_info(id){
    var container = document.getElementById('control-contents');
    MT.App.TabContainer.prototype['selectTab'](container, 'info');    
    var log = BUILD_LOG[id];
    var str =  '<div class="taginfo-misc"><table>';
    str += '<tr><th>id: </th><td>' + log.id + '</td></tr>';
    str += '<tr><th>tagname</th><td>' + log.tag + '</td></tr>';
    if (TIMING)
        str += '<tr><th>time</th><td>' + log.elapsed + '</td></tr>';
    str += '</table></div>';
    str += '<div class="taginfo-output"><pre>' + log.out + '</pre></div>';
    getByID('tag-info').innerHTML = str;
    
}

var CURRENT_VARS;
var VARS_CACHE = new Object;
var VARS_CACHE_INTERVAL = 100;

function get_cached_vars(cache_id) {
    if (cache_id <= 0) return;
    var cache;
    if (VARS_CACHE[cache_id]) {
        cache = VARS_CACHE[cache_id];
    }
    else {
        cache = get_current_vars( cache_id * VARS_CACHE_INTERVAL - 1);
        VARS_CACHE[cache_id] = cache;
    }
    var stash = new Array();
    for (var k in cache){
        stash[k] = cache[k];
    }
    return stash;
}

function get_current_vars(id){
    if (id < 0) return [];
    var cache_id = Math.floor(id / VARS_CACHE_INTERVAL);
    var stash = get_cached_vars(cache_id);
    if (!stash) stash = new Array();
    var i = cache_id * VARS_CACHE_INTERVAL;
    while (i <= id) {
        var log = BUILD_LOG[i++];
        if (log.type != 'diff_vars')
            continue;
        var diff = log.diff;
        for (var j = 0; j < diff.length; j++){
            stash[diff[j].name] = diff[j];
        }
    }
    CURRENT_VARS = stash;
    return stash;
}

function vars_to_table(varlist) {
    var elements = new Array();
    var out = document.createElement( "div" );
    for (var i in varlist) {
        var v = varlist[i];
        if ((!v['status'] || v['status'] == 'nla') && !v.exist) continue;
        var div_key = document.createElement( "div" );
        DOM.addClassName(div_key, 'var-key');
        div_key.innerHTML = v.name; 
        var div_val = document.createElement( "div" );
        DOM.addClassName(div_val, 'var-val');
        if (v['status']) {
            if (v.status == 'new')
                DOM.addClassName(div_val, 'new-var');
            else if (v.status == 'gone') {
                DOM.addClassName(div_val, 'gone-var');
            }
        }
        var val = (v.val && 'object' == typeof v.val)
                ? Object.toJSON(v.val)
                : v.val;
        DOM.addEventListener(div_val, 'mouseover', show_var_value );
        DOM.addEventListener(div_val, 'mouseout', hide_var_value );
        div_val.innerHTML = val;

        var div = document.createElement( "div" );
        div.appendChild(div_key);
        div.appendChild(div_val);
        out.appendChild(div);
    }
    return out;
}

function diff_vars(old_vars, new_vars) {
    var out = '';
    var i = 0;
    var result = new Object();
    for (var key in new_vars) {
        result[key] = new_vars[key];
        result[key]['status'] = "new";
    }
    for (var key in old_vars) {
        var v = old_vars[key];
        if ( result[key] ) {
            if (result[key].exist) {
                if ( v.val == result[key].val )
                    result[key]['status'] = 'same';
            }
            else {
                if ( v.exist )
                    result[key]['status'] = 'gone';
                else 
                    result[key]['status'] = 'nla';
            }
        }
        else {
            result[key] = v;
            result[key]['status'] = 'gone';
        }
    }
    return result;
}

var SELECTED_LOG_ID = 0;

function select_tag(id) {
    var container = document.getElementById('control-contents');
    MT.App.TabContainer.prototype['selectTab'](container, 'info');    
    jump_tag(id,0);
}

function jump_tag(id, with_scroll) {
    var old_id = SELECTED_LOG_ID;
    var new_id = id;
    var step_types = { 'pre': 1,
                       'post': 1,
                       'text': 1 };
    while (1) {
        if (step_types[BUILD_LOG[new_id].type]) break;
        new_id++;
        if (new_id >= BUILD_LOG.length) return;
    }
    SELECTED_LOG_ID = new_id;

    var old_dom = getByID('log-' + old_id);
    var old_data = BUILD_LOG[old_id];
    if (old_data) {
        if (old_data.type == 'post')
            DOM.removeClassName(getByID('log-' + old_data.pair_id), 'selected-log-post');
        else
            DOM.removeClassName(old_dom, 'selected-log');
    }

    var new_data = BUILD_LOG[new_id];
    var new_dom = getByID('log-' + new_id);
    if (new_data.type == 'post')
        DOM.addClassName(getByID('log-' + new_data.pair_id), 'selected-log-post');
    else
        DOM.addClassName(new_dom, 'selected-log');
    if (with_scroll)
        window.scroll(0, new_dom.offsetTop - 220);
    show_log_info(new_id);
    var parent = getByID('info-vars');
    while (parent.childNodes.length) parent.removeChild(parent.childNodes.item(0));
    var old_vars = get_current_vars(old_id);
    var new_vars = get_current_vars(new_id);
    var table = vars_to_table(diff_vars(old_vars,new_vars));
    parent.appendChild(table);
}

function step_tag(direction) {
    var reverse = direction == 'prev' ? 1 : 0;
    var old_id = SELECTED_LOG_ID;
    var new_id = old_id;
    var step_types = { 'pre': 1,
                       'post': 1,
                       'text': 1 };
    while (1) {
        if (reverse) {
            new_id--;
            if (new_id < 0) return;
        }
        else {
            new_id++;
            if (new_id >= BUILD_LOG.length) return 0;
        }
        if (step_types[BUILD_LOG[new_id].type]) break;
    }
    SELECTED_LOG_ID = new_id;

    var old_dom = getByID('log-' + old_id);
    var old_data = BUILD_LOG[old_id];
    if (old_data) {
        if (old_data.type == 'post')
            DOM.removeClassName(getByID('log-' + old_data.pair_id), 'selected-log-post');
        else
            DOM.removeClassName(old_dom, 'selected-log');
    }

    var new_data = BUILD_LOG[new_id];
    var new_dom = getByID('log-' + new_id);
    if (new_data.type == 'post')
        DOM.addClassName(getByID('log-' + new_data.pair_id), 'selected-log-post');
    else
        DOM.addClassName(new_dom, 'selected-log');
    window.scroll(0, new_dom.offsetTop - 220);
    show_log_info(new_id);
    var parent = getByID('info-vars');
    while (parent.childNodes.length) parent.removeChild(parent.childNodes.item(0));
    var old_vars = get_current_vars(old_id);
    var new_vars = get_current_vars(new_id);
    var table = vars_to_table(diff_vars(old_vars,new_vars));
    parent.appendChild(table);
    return 1;
}

function table_line( head, content ) {
    return '<tr><th>' + head + '</th><td>' + content + '</td></tr>';
}

function show_log_info(id){
    var log = BUILD_LOG[id];
    var misc = '';
    var out = '';
    switch(log.type) {
        case 'enter_build':
            out += 'enter build';
            break;
        case 'start_tokens':
            out += 'tokens';
            break;
        case 'start_tokens_else':
            out += 'tokens else';
            break;
        case 'end_tokens':
            out += 'tokens';
            break;
        case 'exit_build':
            out += 'exit build';
            break;
        case 'diff_vars':
            out += 'diff var';
            break;
        case 'diff_stash':
            out += 'diff stash';
            break;
        case 'error':
            misc += table_line('kind', 'error');
            break;
        case 'pre':
            if (log.block) {
                misc += table_line('kind', 'pre block');
            }
            else {
                misc += table_line('kind', 'pre function');
            }
 /*           <mt:if buildtracer_debug>misc += table_line('id', log.id);</mt:if>
 */
            misc += table_line('tagname', log.tag);
            if (log.args) {
                misc += table_line('args', log.args);
            }
            break;
        case 'post':
            misc += table_line('kind', 'post proccess');
            var pair = BUILD_LOG[log.pair_id];
            misc += table_line('tagname', pair.tag);
            if (TIMING)
                misc += table_line('elapsed', log.elapsed);
            out += '<pre>' + log.out + '</pre>';
            break;
        case 'text':
            misc += table_line('kind', 'text');
            out += '<pre>' + log.out + '</pre>';
            break;
        default:
            break;
    }
    if (misc) misc = '<table>' + misc + '</table>';
    getByID('info-misc').innerHTML = misc;
    getByID('info-output').innerHTML = out;
}

function var_diff(log){

}

function stash_diff(log){

}

function print_tracer(loglist) {
    var canvas = getByID('tracer');
    var out = '';
    for (var i in loglist) {
        var log = loglist[i];
        switch(log.type) {
            case 'enter_build':
                out += '<div class="build-log-element';
                if (log.depth)
                    out += '-nest';
                out += '">';
                break;
            case 'start_tokens':
                out += '<div class="tokens"></div>';
                break;
            case 'start_tokens_else':
                out += '<div class="tokens-else"></div>';
                break;
            case 'end_tokens':
                break;
            case 'exit_build':
                out += '</div>';
                break;
            case 'diff_vars':
/*
                out += '<div class="diff-section diff-vars">';
                out += var_diff(log);
                out += '</div>';
*/
                break;
            case 'diff_stash':
/*
                out += '<div class="diff-section diff-stash">';
                out += stash_diff(log);
                out += '</div>';
*/
                break;
            case 'error':
                out += '<div class="error">ERROR: <mt:var out></div>';
                break;
            case 'pre':
                out += '<div id="log-';
                out += log.id;
                out += '" class="'
                if (log.error)
                    out += 'error ';
                if (log.block) {
                    out += 'block-tag';
                }
                else {
                    out += 'function-tag';
                }
                out += '">';
                out += '<span class="tag-name"><a href="javascript:select_tag(';
                out += log.id;
                out += ', 0)">mt:';
                out += log.tag;
                out += '</a></span>';
                if (log.args) {
                    out += '<span class="tag-args">';
                    out += log.args;
                    out += '</span>';
                }
                break;
            case 'post':
                if (log.block) {
                    out += '<span id="log-';
                    out += log.id;
                    out += '" class="block-output">';
                    if (log.trimed_out) {
                        out += log.trimed_out;
                    }
                    else {
                        out += '(no output)';
                    }
                    out += '</span>';
                    out += '<span class="tag-name">/mt:';
                    out += log.tag;
                    out += '</span>';
                    if (TIMING) {
                        out += '<span class="time-elapsed">';
                        out += log.elapsed;
                        out += '&nbsp;/&nbsp;';
                        out += log.elapsed_total;
                        out += '</span>';
                    }
                    out += '</div>';
                }
                else {
                    out += '<span id="log-';
                    out += log.id;
                    out += '" class="function-output">';
                    if (log.trimed_out) {
                        out += log.trimed_out;
                    }
                    else {
                        out += '(no output)';
                    }
                    out += '</span>';
                    if (TIMING) {
                        out += '<span class="time-elapsed">';
                        out += log.elapsed;
                        out += '&nbsp;/&nbsp;';
                        out += log.elapsed_total;
                        out += '</span>';
                    }
                    out += '</div>';
                }
                break;
            case 'text':
                out += '<div id="log-';
                out += log.id;
                out += '" class="plain-text"><pre>'
                out += log.out;
                out += '</pre></div>'
                break;
            default:
                break;
        }
    }
    canvas.innerHTML = out;
}

function print_output(loglist) {
    var canvas = getByID('tracer');
    var out = '';
    var len = loglist.length;
    var i = 0;
    while ( i < len) {
        var log = loglist[i];
        switch(log.type) {
            case 'error':
                out += '<div class="error">ERROR: <mt:var out></div>';
                break;
            case 'pre':
                if (log.block) {
                    out += '<pre class="output block-tag block-output';
                    if (log.error)
                        out += ' error';
                    out += '">';
                }
                else {
                    out += '<pre class="output function-tag function-output';
                    if (log.error)
                        out += ' error';
                    out += '">';
               }
                out += '<a href="javascript:show_tag_info(';
                out += log.id;
                out += ')">';
                out += log.out || '-';
                out += '</a></pre>';
                i = log.pair_id;
                break;
            case 'text':
                out += '<pre class="output plain-text">'
                out += log.out;
                out += '</pre>'
                break;
            default:
                break;
        }
        i++;
    }
    canvas.innerHTML = out;
}

function show_var_value(event) {
    var val = event.target.innerHTML;
    var pu = getByID('bt_popup');
    pu.innerHTML = '<pre>' + val + '</pre>';
    DOM.setLeft(pu, event.clientX + 20);
    DOM.setTop(pu, event.clientY + 20);
    DOM.removeClassName('bt_popup', 'hidden');
}

function hide_var_value(event) {
    DOM.addClassName('bt_popup', 'hidden');
}


/*
 *     AUTOWALKs
 */

var AUTOWALK;

function toggle_autowalk() {
    if (AUTOWALK) {
        AUTOWALK = 0;
        getByID('button-go-auto').style.backgroundPosition = '-112px 0';
    }
    else {
        AUTOWALK = 1;
        getByID('button-go-auto').style.backgroundPosition = '-128px 0';
        do_autowalk();
    }
}

function do_autowalk() {
    if(AUTOWALK) {
        if (step_tag('next')){
            setTimeout('do_autowalk()', 100 );
        }
        else {
            AUTOWALK = 0;
            getByID('button-go-auto').style.backgroundPosition = '-112px 0';

        }
    }
}
