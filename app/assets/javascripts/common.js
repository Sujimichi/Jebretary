$(function(){
  $("#new_instance").show('slow');
  clearTimeout(index_search_timer);
});


var index_search_timer = null
var craft_version_timer = null



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
    alert("There was an Error")
    alert(r.responseText)
  };
  $.ajax({ url: url, data: data, type: type, success: callback, error: wrapped_error, dataType: 'script' });
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
  ajax_get(craft_id + "/edit", {data: "message_form", sha_id: commit}, function(){
  });
};

function update_message(div, craft_id, commit, original_message){
  $(div).find('#message').bind("blur", function(){
    $('.message_form').hide();

    var new_message = $(this).val();
    if(original_message != new_message){
      ajax_put(craft_id, {update_message: new_message, commit_to_edit: commit}, function(){});
    }
  poll_craft_version();
  });
  $(div).find('#message').focus()

};
