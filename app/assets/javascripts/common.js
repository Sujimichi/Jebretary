$(function(){
  clearTimeout(index_search_timer);
});


var index_search_timer = null
var craft_version_timer = null
var rails_env = $('#rails_env').val();
var show_setup_poller_help_timer = undefined


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
    if(rails_env == "development"){
      alert("There was an Error");
      alert(r.status)
      alert(e)
      $('#content').html(r.responseText);
    };
  };
  $.ajax({ url: url, data: data, type: type, success: callback, error: wrapped_error, dataType: 'script' });
};

var setup_timer = null
function poll_for_updated_instance(){
  clearTimeout(setup_timer);
  setup_timer = setTimeout(function(){
    instance_id = $('#instance_id').val();
    ajax_get(instance_id, {}, function(){});
  }, 1000);
};

function poll_for_updated_list(){
  var campaign_id = $('#campaign_id').val();
  if(campaign_id != undefined){
    var data = {id: campaign_id};
    ajax_get("/campaigns/"+ campaign_id, data, function(){
      clearTimeout(index_search_timer);
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


function change_message(div, current_text, craft_id, commit){
  clearTimeout(craft_version_timer);
  clearTimeout(index_search_timer);
  ajax_get("/crafts/" + craft_id + "/edit", {data: "message_form", sha_id: commit}, function(){
  });
};

function update_message(div, craft_id, commit, original_message){

  $(div).find('#message').bind("blur", function(){
    var new_message = $(this).val();
    if(original_message != new_message){
      ajax_put("/crafts/" + craft_id, {update_message: new_message, sha_id: commit}, function(){});
    }else{
      $('.message_form').dialog();
      $('.message_form').dialog( "close" );
      restart_appropriate_poller()
    };

  });
};


var open_dialogs = {}

function dialog_open(div_id){
  if(open_dialogs[div_id] == true){return true}else{return false}
};


var help_ref = {}


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
        position: ['center', 250],
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


function restart_appropriate_poller(){
  var campaign = $('#campaign_id').val();
  if(campaign == undefined){
    poll_craft_version();
  }else{
    poll_for_updated_list()
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
