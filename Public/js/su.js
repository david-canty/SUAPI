$(document).ready(function() {
    
    var baseUrl = '/api';
    
    // School create submit
    $('#schools-container').on('click', '.school-create-submit', function(e) {
        
        e.preventDefault();
        $('.alert').remove();
        var form = $(this).closest('form');
        
        $.ajax({
        url: baseUrl + '/schools',
        type: 'POST',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href','/schools');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            var schoolNameInput = form.find('input[name=schoolName]');
            schoolNameInput.focus()
            schoolNameInput.closest('.validation-wrapper').append('<div class="alert alert-danger mb-4" role="alert"><p>' + validationErrorString + '</p></div>');
            $('.alert').hide().fadeIn(500);
        });
    });

    // School update submit
    $('#schools-container').on('click', '.school-update-submit', function(e) {
        
        e.preventDefault();
        $('.alert').remove();
        var form = $(this).closest('form');
        var schoolId = form.data('id');

        $.ajax({
        url: baseUrl + '/schools/' + schoolId,
        type: 'PUT',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href', '/schools');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            var schoolNameInput = form.find('input[name=schoolName]');
            schoolNameInput.focus();
            schoolNameInput.closest('.validation-wrapper').append('<div class="alert alert-danger mb-4" role="alert"><p>' + validationErrorString + '</p></div>');
            $('.alert').hide().fadeIn(500);
        });
    });
    
    // School delete submit
    $('#schools-container').on('click', '.school-delete-submit', function(e) {
       
        e.preventDefault();
        var schoolId = $(this).data('id');
        $('#school-delete-modal').modal('hide');
        
        $.ajax({
        url: baseUrl + '/schools/' + schoolId,
        type: 'DELETE',
        success: function(response) {
                
            window.location.reload(true);
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            alert('Error: ' + xhr.status + ' ' + xhr.statusText);
        });
    });
    
    // User create submit
    $('#user-create-submit').click(function(e) {
        
        e.preventDefault();
        e.stopPropagation();
        
        var form = $(this).closest('form');
        form.addClass('was-validated');
        
        if (form[0].checkValidity() === false) {
            return false
        }

        $.ajax({
        url: baseUrl + '/users',
        type: 'POST',
        data: form.serialize(),
        success: function(response) {

            $(location).attr('href','/users');

        }}).fail(function(xhr, ajaxOptions, thrownError) {

            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;

            alert(validationErrorString);
        });
    });
    
    // User update submit
    $('#user-update-submit').click(function(e) {
        
        e.preventDefault();
        e.stopPropagation();
        
        var form = $(this).closest('form');
        var userId = form.data('id');
        form.addClass('was-validated');
        
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/users/' + userId,
        type: 'PUT',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href', '/users');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // User delete submit
    $('#users-container').on('click', '.user-delete-submit', function(e) {
        
        $('#user-delete-modal').modal('hide');
        
        e.preventDefault();
        
        var userId = $(this).data('id');
        
        $.ajax({
        url: baseUrl + '/users/' + userId,
        type: 'DELETE',
        success: function(response) {
            
            window.location.reload(true);
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // User disable
    $('#users-container').on('click', '.disable-user', function(e) {
        
        e.preventDefault();
        
        var userId = $(this).data('id');
        var userEnabled = $(this).data('enabled');
        var json = {"isEnabled": userEnabled};
        
        $.ajax({
        url: baseUrl + '/users/' + userId + '/status',
        type: 'PATCH',
        data: JSON.stringify(json),
        processData: false,
        contentType: "application/json",
        success: function(response) {
            
           $(location).attr('href', '/users');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Delete modal handlers
    $('#school-delete-modal').on('show.bs.modal', function (e) {
        
        var button = $(e.relatedTarget);
        var recipient = button.data('id');
        $(this).find('.school-delete-submit').attr('data-id', recipient);
    });
    
    $('#user-delete-modal').on('show.bs.modal', function (e) {
        
        var button = $(e.relatedTarget);
        var recipient = button.data('id');
        $(this).find('.user-delete-submit').attr('data-id', recipient);
    });
    
    // Change Password
    $('#password-cancel-submit').click(function(e) {
        
        e.preventDefault();
        window.history.back();
    });
                        
    $('#password-change-submit').click(function(e) {
        
        e.preventDefault();
        e.stopPropagation();
        
        var form = $(this).closest('form');
        var userId = form.data('id');
        form.addClass('was-validated');
        
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/users/' + userId + '/change-password',
        type: 'PATCH',
        data: form.serialize(),
        success: function(response) {
            
            window.history.back();
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Sign in
    $('#sign-in').click(function(e) {
        
        $('.alert').remove();
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        
        $.ajax({
        url: '/sign-in',
        type: 'POST',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href','/');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            $('.validation-wrapper').append('<div class="alert alert-danger mb-4" role="alert"><p>' + validationErrorString + '</p></div>');
            $('.alert').hide().fadeIn(500);
        });
    });
    
    // Sign out
    $('.container').on('click', '#sign-out', function(e) {
        $.ajax({ url: '/sign-out', type: 'POST'});
    });
})
