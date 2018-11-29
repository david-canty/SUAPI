$(document).ready(function() {
    
    var baseUrl = '/api';
    
    // School create submit
    $('#schools-container').on('click', '.school-create-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
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
            
            alert(validationErrorString);
        });
    });

    // School update submit
    $('#schools-container').on('click', '.school-update-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        var schoolId = form.data('id');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }

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
            
            alert(validationErrorString);
        });
    });
    
    // School sort order
    $('#schools-container tbody').sortable({ update: function(event, ui) {
        
        updateSchoolSortOrders();
        
    }}).disableSelection();
    
    updateSchoolSortOrders();
    
    function updateSchoolSortOrders() {
        
        // Update school table sort orders
        $('#schools-container table tr').each(function() {
            $(this).children('td:nth-child(2)').html($(this).index())
        });
        
        // Get array of sorted school ids
        var sortedSchoolIds = $('#schools-container tbody').sortable('toArray');
        
        // Patch each school with new sort order
        $.each(sortedSchoolIds, function(index, schoolId) {
            
            var json = {"sortOrder": index};
            
            $.ajax({
            url: baseUrl + '/schools/' + schoolId + '/sort-order',
            type: 'PATCH',
            data: JSON.stringify(json),
            processData: false,
            contentType: "application/json",
                success: function(response) { }}).fail(function(xhr, ajaxOptions, thrownError) {
                    
                    var statusCode = xhr.status;
                    var statusText = xhr.statusText;
                    var responseJSON = JSON.parse(xhr.responseText);
                    var validationErrorString = responseJSON.reason;
                    
                    alert(validationErrorString);
                });
        });
    }
    
    // School delete submit
    $('#schools-container').on('click', '.school-delete-submit', function(e) {
       
        e.preventDefault();
        
        var schoolId = $(this).data('id');
        $('#school-delete-modal').modal('hide');
        
        $.ajax({
        url: baseUrl + '/schools/' + schoolId,
        type: 'DELETE',
        success: function(response) {
                
            $(location).attr('href','/schools');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
                 
            $(location).attr('href','/schools');
        });
    });
    
    // Year create submit
    $('#years-container').on('click', '.year-create-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        var schoolID = form.find('input[name="schoolID"]').val();
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/years',
        type: 'POST',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href','/schools/' + schoolID + '/years');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Year update submit
    $('#years-container').on('click', '.year-update-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        var yearID = form.data('id');
        var schoolID = form.find('input[name="schoolID"]').val();
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/years/' + yearID,
        type: 'PUT',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href', '/schools/' + schoolID + '/years');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Year sort order
    $('#years-container tbody').sortable({ update: function(event, ui) {
        
        updateYearSortOrders();
        
    }}).disableSelection();
    
    updateYearSortOrders();
    
    function updateYearSortOrders() {
        
        // Update year table sort orders
        $('#years-container table tr').each(function() {
            $(this).children('td:nth-child(2)').html($(this).index())
        });
        
        // Get array of sorted year ids
        var sortedYearIds = $('#years-container tbody').sortable('toArray');
        
        // Patch each year with new sort order
        $.each(sortedYearIds, function(index, yearId) {
            
            var json = {"sortOrder": index};
            
            $.ajax({
            url: baseUrl + '/years/' + yearId + '/sort-order',
            type: 'PATCH',
            data: JSON.stringify(json),
            processData: false,
            contentType: "application/json",
                success: function(response) { }}).fail(function(xhr, ajaxOptions, thrownError) {
                    
                    var statusCode = xhr.status;
                    var statusText = xhr.statusText;
                    var responseJSON = JSON.parse(xhr.responseText);
                    var validationErrorString = responseJSON.reason;
                    
                    alert(validationErrorString);
                });
        });
    }
    
    // Year delete submit
    $('#years-container').on('click', '.year-delete-submit', function(e) {
        
        e.preventDefault();
        
        var yearId = $(this).data('id');
        $('#year-delete-modal').modal('hide');
        
        $.ajax({
        url: baseUrl + '/years/' + yearId,
        type: 'DELETE',
        success: function(response) {
            
            location.reload(true);
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
                 
            location.reload(true);
        });
    });
    
    // Category create submit
    $('#categories-container').on('click', '.category-create-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/categories',
        type: 'POST',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href','/categories');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Category update submit
    $('#categories-container').on('click', '.category-update-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        var categoryId = form.data('id');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/categories/' + categoryId,
        type: 'PUT',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href', '/categories');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Category sort order
    $('#categories-container tbody').sortable({ update: function(event, ui) {
        
        updateCategorySortOrders();
        
    }}).disableSelection();
    
    updateCategorySortOrders();
    
    function updateCategorySortOrders() {
        
        // Update category table sort orders
        $('#categories-container table tr').each(function() {
            $(this).children('td:nth-child(2)').html($(this).index())
        });
        
        // Get array of sorted category ids
        var sortedCategoryIds = $('#categories-container tbody').sortable('toArray');
        
        // Patch each category with new sort order
        $.each(sortedCategoryIds, function(index, categoryId) {
            
            var json = {"sortOrder": index};
            
            $.ajax({
            url: baseUrl + '/categories/' + categoryId + '/sort-order',
            type: 'PATCH',
            data: JSON.stringify(json),
            processData: false,
            contentType: "application/json",
            success: function(response) { }}).fail(function(xhr, ajaxOptions, thrownError) {
                
                var statusCode = xhr.status;
                var statusText = xhr.statusText;
                var responseJSON = JSON.parse(xhr.responseText);
                var validationErrorString = responseJSON.reason;
                
                alert(validationErrorString);
            });
        });
    }
    
    // Category delete submit
    $('#categories-container').on('click', '.category-delete-submit', function(e) {
        
        e.preventDefault();
        
        var categoryId = $(this).data('id');
        $('#category-delete-modal').modal('hide');
        
        $.ajax({
        url: baseUrl + '/categories/' + categoryId,
        type: 'DELETE',
        success: function(response) {
            
            $(location).attr('href','/categories');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
            
            $(location).attr('href','/categories');
        });
    });
    
    // Size create submit
    $('#sizes-container').on('click', '.size-create-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/sizes',
        type: 'POST',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href','/sizes');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Size update submit
    $('#sizes-container').on('click', '.size-update-submit', function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        var sizeId = form.data('id');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        $.ajax({
        url: baseUrl + '/sizes/' + sizeId,
        type: 'PUT',
        data: form.serialize(),
        success: function(response) {
            
            $(location).attr('href', '/sizes');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Size sort order
    $('#sizes tbody').sortable({ update: function(event, ui) {

        updateSizeSortOrders();

    }}).disableSelection();

    updateSizeSortOrders();
    
    function updateSizeSortOrders() {

        // Update size table sort orders
        var pageOffset = $('#sizes').data('pageoffset');
        $('#sizes table tr').each(function() {
            $(this).children('td:nth-child(2)').html($(this).index() + pageOffset)
        });

        // Get array of sorted size ids
        var sortedSizeIds = $('#sizes tbody').sortable('toArray');

        // Patch each size with new sort order
        $.each(sortedSizeIds, function(index, sizeId) {

            var json = {"sortOrder": index + pageOffset};

            $.ajax({
            url: baseUrl + '/sizes/' + sizeId + '/sort-order',
            type: 'PATCH',
            data: JSON.stringify(json),
            processData: false,
            contentType: "application/json",
                success: function(response) { }}).fail(function(xhr, ajaxOptions, thrownError) {

                    var statusCode = xhr.status;
                    var statusText = xhr.statusText;
                    var responseJSON = JSON.parse(xhr.responseText);
                    var validationErrorString = responseJSON.reason;

                    alert(validationErrorString);
                });
        });
    }
    
    // Sizes per page
    $('#sizes-container').on('click', '.btn-toolbar .btn', function(e) {
        e.preventDefault();
        var sizesPerPage = $(this).html();
        document.cookie = "sizes-per-page=" + sizesPerPage + ";"
        sizePageChangedTo(1);
    });
    
    // Size pagination
    $('#sizes-container').on('click', '.page-item a', function(e) {
        e.preventDefault();
        var clickedIndex = $(this).closest('li').index();
        sizePageChangedTo(clickedIndex + 1);
    });
    
    function sizePageChangedTo(newPage) {
        
        $.ajax({
        url: "/sizes?page=" + newPage,
        type: "GET",
        success: function(response) {
            
            var $sizes = $(response).find('#sizes');
            $("#sizes").replaceWith($sizes);
            var $pagination = $(response).find('#pagination');
            $("#pagination").replaceWith($pagination);
            
            $('#sizes-container tbody').sortable({ update: function(event, ui) {
                
                updateSizeSortOrders();
                
            }}).disableSelection();
        }
            
        }).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    }
    
    // Size delete submit
    $('#sizes-container').on('click', '.size-delete-submit', function(e) {
        
        e.preventDefault();
        
        var sizeId = $(this).data('id');
        $('#size-delete-modal').modal('hide');
        
        $.ajax({
        url: baseUrl + '/sizes/' + sizeId,
        type: 'DELETE',
        success: function(response) {
            
            $(location).attr('href','/sizes');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
                 
            $(location).attr('href','/sizes');
        });
    });
    
    // Item create submit
    $('#item-create-submit').click(function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        var formData = new FormData(form[0]);
        
        $.ajax({
        url: baseUrl + '/items',
        type: 'POST',
        data: formData,
        cache: false,
        contentType: false,
        processData: false,
        success: function(response) {
            
            $(location).attr('href','/items');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Item update submit
    $('#item-update-submit').click(function(e) {

        e.preventDefault();
        
        var form = $(this).closest('form');
        var itemId = form.data('id');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        var formData = new FormData(form[0]);
        
        $.ajax({
        url: baseUrl + '/items/' + itemId,
        type: 'PUT',
        data: formData,
        cache: false,
        contentType: false,
        processData: false,
        success: function(response) {
            
            $(location).attr('href', '/items');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
                  
    // Item images
    $( "#item-images-container" ).on( "click", "#images-upload-submit", function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        var itemId = form.data('id');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        var formData = new FormData(form[0]);
        
        $.ajax({
        url: baseUrl + '/items/' + itemId + '/images',
        type: 'POST',
        data: formData,
        cache: false,
        contentType: false,
        processData: false,
        success: function(response) {
            
            location.reload(true);
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
                  
    // Item image sort order
    $('#item-images-container #item-images ul').sortable({ update: function(event, ui) {
        
        updateItemImageSortOrders();
        
    }}).disableSelection();
    
    updateItemImageSortOrders();
    
    function updateItemImageSortOrders() {
        
        // Get form and item id
        var form = $('#itemImagesForm');
        var itemId = form.data('id');
        
        // Get array of sorted image ids
        var sortedImageIds = $('#item-images ul').sortable('toArray');
        
        // Patch each image with new sort order
        $.each(sortedImageIds, function(index, imageId) {
            
            var json = {"sortOrder": index};
            
            $.ajax({
            url: baseUrl + '/items/' + itemId + '/images/' + imageId + '/sort-order',
            type: 'PATCH',
            data: JSON.stringify(json),
            processData: false,
            contentType: "application/json",
                success: function(response) {  }}).fail(function(xhr, ajaxOptions, thrownError) {
                    
                    var statusCode = xhr.status;
                    var statusText = xhr.statusText;
                    var responseJSON = JSON.parse(xhr.responseText);
                    var validationErrorString = responseJSON.reason;
                    
                    alert(validationErrorString);
                });
        });
    }
    
    $( "#item-images" ).on( "click", ".image-delete-button", function(e) {
        
        e.preventDefault();
        
        var itemImagesForm = $('#itemImagesForm');
        var itemId = itemImagesForm.data('id');
        
        var li = $(this).closest('li');
        var imageId = li.attr('id');
        
        $.ajax({
        url: baseUrl + '/items/' + itemId + '/images/' + imageId,
        type: 'DELETE',
        success: function(response) {
            
            location.reload(true);
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Item stock update submit
    $( "#item-stock-container" ).on( "click", "#item-stock-submit", function(e) {
        
        e.preventDefault();
        
        var form = $(this).closest('form');
        var itemId = form.data('id');
        
        form.addClass('was-validated');
        if (form[0].checkValidity() === false) {
            return false
        }
        
        var formData = new FormData(form[0]);
                     
        $.ajax({
        url: baseUrl + "/items/" + itemId + "/stock",
        type: "PATCH",
        data: formData,
        cache: false,
        contentType: false,
        processData: false,
        success: function(response) {

            $(location).attr('href', '/items');

        }}).fail(function(xhr, ajaxOptions, thrownError) {

            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // Item delete submit
    $('#items-container').on('click', '.item-delete-submit', function(e) {
        
        $('#item-delete-modal').modal('hide');
        
        e.preventDefault();
        
        var itemId = $(this).data('id');
        
        $.ajax({
        url: baseUrl + '/items/' + itemId,
        type: 'DELETE',
        success: function(response) {
            
            $(location).attr('href', '/items');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    // User create submit
    $('#user-create-submit').click(function(e) {
        
        e.preventDefault();
        
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
            
            $(location).attr('href', '/users');
            
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
    
    $('#year-delete-modal').on('show.bs.modal', function (e) {
        var button = $(e.relatedTarget);
        var recipient = button.data('id');
        $(this).find('.year-delete-submit').attr('data-id', recipient);
    });
    
    $('#category-delete-modal').on('show.bs.modal', function (e) {
        var button = $(e.relatedTarget);
        var recipient = button.data('id');
        $(this).find('.category-delete-submit').attr('data-id', recipient);
    });
    
    $('#size-delete-modal').on('show.bs.modal', function (e) {
        var button = $(e.relatedTarget);
        var recipient = button.data('id');
        $(this).find('.size-delete-submit').attr('data-id', recipient);
    });
    
    $('#item-delete-modal').on('show.bs.modal', function (e) {
        var button = $(e.relatedTarget);
        var recipient = button.data('id');
        $(this).find('.item-delete-submit').attr('data-id', recipient);
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
    
//    // Sign out
//    $('.container').on('click', '#sign-out', function(e) {
//        $.ajax({ url: '/sign-out', type: 'POST'});
//    });

    // Orders
    
    $('#orders-container').on('click', '.order-status', function(e) {
     
        e.preventDefault();
        
        var table = $(this).closest('table');
        var orderId = table.data('id');
        var orderStatus = $(this).text();
        
        var json = {"orderStatus": orderStatus};
        
        $.ajax({
        url: baseUrl + '/orders/' + orderId + '/status',
        type: 'PATCH',
        data: JSON.stringify(json),
        processData: false,
        contentType: "application/json",
        success: function(response) {
                
            location.reload(true);
                
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
    
    $('#order-cancel-return-modal').on('show.bs.modal', function (e) {
        
        var button = $(e.relatedTarget);
        var orderId = button.data('order-id');
        var paymentMethod = button.data('payment-method');
        var orderTotal = button.data('order-total');
        var modalAction = button.data('action');
        
        var modal = $(this);
        var modalTitle = '';
        var modalBody = '';
        var paymentMethodBody = '';
        var paddedOrderId = pad(orderId, 6);
        
        switch(paymentMethod) {
            
            case 'BACS transfer':
            
            paymentMethodBody = '<br/><p>The payment method for this order was BACS transfer. If the customer has already paid, please remember to refund the full amount of &pound;' + orderTotal + '.</p>';
            break;
            
            case 'School bill':
            
            paymentMethodBody = '<br/><p>The payment method for this order was add to school bill. If the school bill has already been adjusted, please remember to refund the full amount of &pound;' + orderTotal + '.</p>';
            break;
            
            default:
            
            paymentMethodBody = '<br/><p>The payment method for this order was credit card. A refund for the full amount of &pound;' + orderTotal + ' will be issued immediately to ' + paymentMethod.toLowerCase() + '.</p>';
            break;
        }
        
        switch(modalAction) {
            
            case 'cancel':
            
            modalTitle = 'Cancel order?';
            modalBody = '<p>Do you wish to cancel order no ' + paddedOrderId + '?</p>' + paymentMethodBody;
            modal.find('.order-cancel-return-submit').attr('data-order-status', 'Cancelled');
            
            break;
            
            case 'return':
            
            modalTitle = 'Return order?';
            modalBody = '<p>Do you wish to return order no ' + paddedOrderId + '?</p>' + paymentMethodBody;
            modal.find('.order-cancel-return-submit').attr('data-order-status', 'Returned');
            
            break;
        }
        
        modal.find('.order-cancel-return-submit').attr('data-order-id', orderId);
        modal.find('.modal-title').text(modalTitle);
        modal.find('.modal-body').html(modalBody);
    });
    
    function pad (str, max) {
        str = str.toString();
        return str.length < max ? pad("0" + str, max) : str;
    };
    
    $('#orders-container').on('click', '.order-cancel-return-submit', function(e) {
        
        $('#order-cancel-return-modal').modal('hide');
        
        e.preventDefault();
        
        var orderId = $(this).data('order-id');
        var orderStatus = $(this).data('order-status');
        
        var json = {"orderStatus": orderStatus};
        
        $.ajax({
        url: baseUrl + '/orders/' + orderId + '/status',
        type: 'PATCH',
        data: JSON.stringify(json),
        processData: false,
        contentType: "application/json",
        success: function(response) {
            
            $(location).attr('href','/orders');
            
        }}).fail(function(xhr, ajaxOptions, thrownError) {
            
            var statusCode = xhr.status;
            var statusText = xhr.statusText;
            var responseJSON = JSON.parse(xhr.responseText);
            var validationErrorString = responseJSON.reason;
            
            alert(validationErrorString);
        });
    });
    
});
