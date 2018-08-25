$(document).ready(function() {
    
    var baseUrl = "/api"
    
    // Create school submit
    $( "#schools-container" ).on( "click", ".school-create-submit", function(e) {
        
        $('.validation-error').remove();
        e.preventDefault();
        
        var form = $(this).closest('form');
        
        $.ajax({
        url: baseUrl + "/schools",
        type: "POST",
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr("href","/schools");
        }
            
        }).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            if (statusCode == 500 || statusText == "Bad Request") {
                
                alert("Error: " + statusCode + " " + statusText);
                
            } else {
                
                var schoolNameInput = form.find('input[name=schoolName]');
                schoolNameInput.focus();
                schoolNameInput.closest('.validation-wrapper').append('<div class="validation-error p-0 mb-3"><p>' + validationErrorString + '</p></div>');
                $('.validation-error').hide().fadeIn(500);
            }
        });
    });

    
    // Delete school submit
    $( "#schools-container" ).on( "click", ".school-delete-submit", function(e) {
       
        e.preventDefault();
        var schoolId = $(this).data("id");
        $("#school-delete-modal").modal("hide");
        
        $.ajax({
        url: baseUrl + "/schools/" + schoolId,
        type: "DELETE",
        success: function(response) {
                
            window.location.reload(true);
        }
            
        }).fail(function(xhr, ajaxOptions, thrownError) {
            
            alert("Error: " + xhr.status + " " + xhr.statusText);
        });
    });
    
    // Delete modal handlers
    $('#school-delete-modal').on('show.bs.modal', function (event) {
        var button = $(event.relatedTarget);
        var recipient = button.data('id');
        $(this).find('.school-delete-submit').attr('data-id', recipient);
    });
    
})
