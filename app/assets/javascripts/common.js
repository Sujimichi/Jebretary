$(function(){
  $("#new_instance").show('slow');
  clearTimeout(index_search_timer);
});


var index_search_timer = null

function poll_for_updated_list(){
  var campaign_id = $('#campaign_id').val();
  var data = {id: campaign_id};

  $.ajax({ url: "/campaigns/"+ campaign_id, data: data, type: "GET", success: function(data,textStatus){
    clearTimeout(index_search_timer);
    index_search_timer = setTimeout(function(){
      poll_for_updated_list();
    }, 2000);
  }, error: function(r,t,e){
    //alert("test from error" + r.status)
    //alert(r.responseText);
    $('#campaigns_list').html(r.responseText);
  }, dataType: 'script' });
};



var craft_version_timer = null

function poll_craft_version(){
  var craft_id = $('#craft_id').val();
  var data = {id: craft_id};
  $.ajax({ url: "/crafts/"+ craft_id, data: data, type: "GET", success: function(data,textStatus){
    clearTimeout(craft_version_timer);
    craft_version_timer = setTimeout(function(){
      poll_craft_version();
    }, 2000);
    //alert("respone returned test")
  }, error: function(r,t,e){
    //alert("test from error" + r.status)
    //alert(r.responseText);
    $('#campaigns_list').html(r.responseText);
  }, dataType: 'script' });
};
