

var index_search_timer = null

function poll_for_updated_list(){
  //alert("poll called")
  var campaign_id = $('#campaign_id').val();
  var data = {id: campaign_id};
  $.ajax({ url: "/campaigns/"+ campaign_id, data: data, type: "GET", success: function(data,textStatus){
    clearTimeout(index_search_timer);
    index_search_timer = setTimeout(function(){
      poll_for_updated_list();
    }, 2000);
    //alert("respone returned test")
  }, error: function(r,t,e){
    //alert("test from error" + r.status)
    //alert(r.responseText);
    $('#campaigns_list').html(r.responseText);
  }, dataType: 'script' });
};
