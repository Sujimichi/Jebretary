

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
