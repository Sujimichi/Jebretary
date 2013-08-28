$(function(){
  clearTimeout(index_search_timer);
});


var index_search_timer = null
var craft_version_timer = null
var rails_env = $('#rails_env').val();



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
    //if(rails_env == "development"){
      //alert("There was an Error");
      $('#content').html(r.responseText);
    //};
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
  var data = {id: campaign_id};
  ajax_get("/campaigns/"+ campaign_id, data, function(){
    clearTimeout(index_search_timer);
    index_search_timer = setTimeout(function(){
      poll_for_updated_list();
    }, 2000);
  });
};


function poll_craft_version(){
  var craft_id = $('#craft_id').val();
  var data = {id: craft_id};
  ajax_get("/crafts/"+ craft_id, data, function(){
    clearTimeout(craft_version_timer);
    craft_version_timer = setTimeout(function(){
      poll_craft_version();
    }, 2000);
  });
};


function change_message(div, current_text, craft_id, commit){
  clearTimeout(craft_version_timer);
  clearTimeout(index_search_timer);
  ajax_get("/crafts/" + craft_id + "/edit", {data: "message_form", sha_id: commit}, function(){
  });
};

function update_message(div, craft_id, commit, original_message){

  $(div).find('#message').bind("blur", function(){
    $('.message_form').hide();

    var new_message = $(this).val();
    if(original_message != new_message){
      ajax_put("/crafts/" + craft_id, {update_message: new_message, sha_id: commit}, function(){});
    }else{
      restart_appropriate_poller()
    };

  });
  $(div).find('#message').focus()

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
    $('.toggle_deleted_craft_link').html("hide deleted craft")
  }else{
    $(".deleted_craft").hide('fast');
    $('#show_deleted').val('false')
    $('.toggle_deleted_craft_link').html("show deleted craft")
  };
};
