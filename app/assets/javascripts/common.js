$(function(){
  clearTimeout(index_search_timer);
  autohide_flash();
});

var detect_running_ksp_timer = null
var setup_timer = null
var index_search_timer = null
var craft_version_timer = null
var rails_env = $('#rails_env').val();
var show_setup_poller_help_timer = undefined

var open_dialogs = {}
var help_ref = {}


//AJAX methods GET, POST and DELETE - Generalised methods for making ajax requests
function ajax_get(url, data, callback){
  ajax_send(url, data, callback, "GET")
};
function ajax_post(url, data, callback){
  ajax_send(url, data, callback, "POST")
};
function ajax_put(url, data, callback){
  ajax_send(url, data, callback, "PUT")
};
function ajax_delete(url, data, callback){
  ajax_send(url, data, callback, "DELETE")
};

function ajax_send(url, data, callback, type){
  wrapped_error = function(r,t,e){
    if(r.responseText == "" || r.responseText == "no_update"){
    }else{
      $('#content').html(r.responseText);
    };
  };
  $.ajax({ url: url, data: data, type: type, success: callback, error: wrapped_error, dataType: 'script' });
};


autohide_flash = function(){
  setTimeout(function(){
    $('#flash').slideUp('fast')},
    8000
  );
}


function poll_for_running_instances_of_ksp(){
  clearTimeout(detect_running_ksp_timer);
  ajax_get("launch/", {}, function(){
    detect_running_ksp_timer = setTimeout(function(){
      poll_for_running_instances_of_ksp()
    }, 5000);
  });
};

function poll_for_updated_instance(){
  clearTimeout(setup_timer);
  setup_timer = setTimeout(function(){
    ajax_get($('#instance_id').val(), {}, function(){});
  }, 1000);
};


function poll_for_updated_list(){
  var campaign_id = $('#campaign_id').val();
  if(campaign_id != undefined){
    var data = {id: campaign_id};
    data['sort_opts'] = {}
    data['sort_opts']['vab'] = $('#vab_sort_options').val();
    data['sort_opts']['sph'] = $('#sph_sort_options').val();
    data['search_opts'] = {}
    data['search_opts']['vab'] = $('#vab_search_field').val();
    data['search_opts']['sph'] = $('#sph_search_field').val();

    clearTimeout(index_search_timer);
    ajax_get("/campaigns/"+ campaign_id, data, function(){
      index_search_timer = setTimeout(function(){
        poll_for_updated_list();
      }, 2000);
    });
  };
};


function poll_craft_version(){
  var craft_id = $('#craft_id').val();
  if(craft_id != undefined){
    var data = {id: craft_id};
    ajax_get("/crafts/"+ craft_id, data, function(){
      clearTimeout(craft_version_timer);
      craft_version_timer = setTimeout(function(){
        poll_craft_version();
      }, 2000);
    });
  };
};


function set_search_and_sort_fields(){
  $('#vab_search_field').val("");
  $('#sph_search_field').val("");

  $('#vab_search_field').on("keyup", function(){poll_for_updated_list()});
  $('#sph_search_field').on("keyup", function(){poll_for_updated_list()});

  $('#reset_vab_search').on("click", function(){$('#vab_search_field').val(""); poll_for_updated_list()});
  $('#reset_sph_search').on("click", function(){$('#sph_search_field').val(""); poll_for_updated_list()});

  $('.craft_list_sort').on("change", function(){poll_for_updated_list()})
};

function change_message(div, current_text, craft_id, commit){
  ajax_get("/messages/" + craft_id + "/edit", {message_form: true, sha_id: commit, object: 'craft'}, function(){});
};

function update_message(div, object_id, object_class, commit, original_message){
  if($(div).hasClass("with_untracked_changes")){commit = "most_recent"};
  $('#message').bind("blur", function(){
    var new_message = $(this).val();
    if(original_message != new_message){
      $(".updating_message").show();
      ajax_put("/messages/" + object_id, {object_class: object_class, update_message: new_message, sha_id: commit}, function(){
        $(".updating_message").hide();
      });
    }else{
      $('.message_form').dialog();
      $('.message_form').dialog( "close" );
    };
  });
};

function dialog_open(div_id){
  if(open_dialogs[div_id] == true){return true}else{return false}
};

function move_copy_dialog(){
  $('#move_copy_dialog').dialog({
    position: ['center', 100],
    width: 750,
    height: 'auto',
    closeOnEscape: true,
    buttons: [
      { text: "Move", click: function(){$('#move_submit').click()} },
      { text: "Copy", click: function(){$('#copy_submit').click()} },
      { text: "Cancel", click: function(){$(this).dialog('close')} }
    ]
  })
  $('#move_copy_dialog').find(".submit_button").hide();
};

function delete_craft_dialog(){
  $('#delete_craft_dialog').dialog({
    position: ['center', 100],
    width: 750,
    height: 'auto',
    closeOnEscape: true,
    buttons: [
      { text: "Delete!", click: function(){$('#delete_submit').click()} },
      { text: "Cancel", click: function(){$(this).dialog('close')} }
    ]
  })
  $('#delete_craft_dialog').find(".submit_button").hide();
};


function show_restore_link_for(save){
  $(".restore_link").hide();
  $(save).find(".restore_link").show();
};

function show_current_project_help(version_count){
  var h = ""
  if(version_count == 1){h = "one_version"}else{
    if(version_count <= 4){h = "several_versions"}else{h = "multiple_versions"};
  };
  if(version_count == 0){h = "no_versions"};

  if($('#current_project').find('.untracked').is(':visible')){
    h = "untracked_changes"
  };

  var help_item = "current_project_" + h;
  show_help(help_item, {always_show: true});

  if(h != "untracked_changes"){
    show_help('current_project_commit_message', {always_show: true});
  };
};


function show_help(specific_help, args){
  if(args == undefined){args = {}};

  $('.help_for').each(function(){
    if(specific_help == undefined){
      $('#help_holder').append( $(this).html() );
      help_ref[$(this).attr("id")] = $(this).html();
      $(this).remove();
    }else{
      if($(this).attr("id") == specific_help){
        if(args['always_show'] != true){$('#help_holder').append( $(this).html() )};
        help_ref[$(this).attr("id")] = $(this).html();
        $(this).remove();
      };
    };
  });

  if(args['always_show'] == true && specific_help != undefined){
    $('#help_holder').append(help_ref[specific_help]);
  };

  if(dialog_open('#help_holder') == true){
     $('#help_holder').dialog('option', 'height', 'auto')
  };

  if($('#help_holder').html() != ""){
    if(args['create'] == undefined){args['create'] = function(){}};
    if(args['close'] == undefined){args['close'] = function(){}};

    if(dialog_open('#help_holder') != true){
      $('#help_holder').dialog({
        close: function(){
          $('#help_holder').html("");
          open_dialogs['#help_holder'] = false;
          args['close']()
        },
        position: ['center', 100],
        width: 750,
        height: 'auto',
        closeOnEscape: true,
        buttons: [ { text: "Ok", click: function(){$(this).dialog('close')} } ]
      });
      args['create']()
      open_dialogs['#help_holder'] = true;
    };

  };

  $('#help_holder').bind("blur", function(){
    $('#help_holder').dialog("close");
  });


};

function toggle_save_display(){
  var vis = $('#quicksave_display').is(":visible")
  if(vis == true){
    $('#quicksave_display').hide();
    $('#persistent_display').show();
    $('#active_save_display').val('persistent')
  }else{
    $('#persistent_display').hide();
    $('#quicksave_display').show();
    $('#active_save_display').val('quicksave')
  };

};

function toggle_active_display(){
  var vis = $('#current_project').is(":visible")
  if(vis == true){
    show_campaign_saves();
  }else{
    show_current_project();
  };
};

var auto_switch_display = true
var auto_switch_reset = null
var current_display_type = null

function auto_switch_display_based_on(most_recent_commit){
  current_display_type = most_recent_commit;
  if(auto_switch_display == true){
    if(most_recent_commit == "quicksave"){
      show_campaign_saves();
    }else{
      show_current_project();
    }
  };
};

function auto_show_deleted_craft_link(count){
  if(count == 0){
    $(".show_del_link_container").hide();
  }else{
    $(".show_del_link_container").show();
  };
};

function show_current_project(opts){
  $('#campaign_saves').hide();
  $('#current_project').show();
  $('#active_display').val('current_project')
  if(opts == undefined){var opts = {}};
  clearTimeout(auto_switch_reset);
  if(opts['force'] == true){
    auto_switch_display = false;
    auto_switch_reset = setTimeout(function(){
      auto_switch_display = true;
      auto_switch_display_based_on(current_display_type);
    },300000)
  };
};

function show_campaign_saves(opts){
  $('#current_project').hide();
  $('#campaign_saves').show();
  $('#active_display').val('saves');
  if(opts == undefined){var opts = {}};
  clearTimeout(auto_switch_reset);
  if(opts['force'] == true){
    auto_switch_display = false;
    auto_switch_reset = setTimeout(function(){
      auto_switch_display = true;
      auto_switch_display_based_on(current_display_type);
    },300000)
  };
};

function toggle_deleted_craft(){
  var show_del = $('#show_deleted').val()
  if(show_del == "false"){
    $(".deleted_craft").show('fast');
    $('#show_deleted').val('true')
    $('.show_del_craft_marker').addClass("selected_marker");
    $('.toggle_deleted_craft_link').html("hide deleted craft")
  }else{
    $(".deleted_craft").hide('fast');
    $('#show_deleted').val('false')
    $('.show_del_craft_marker').removeClass("selected_marker");
    $('.toggle_deleted_craft_link').html("show deleted craft")
  };
};
