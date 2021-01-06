(function() {

  let filterInputLeft = document.getElementById('filterInputLeft')
  let filterInputRight = document.getElementById('filterInputRight')

  function syncFilter(e) {
    let filterInputs = [filterInputLeft, filterInputRight];

    for (let filterInput of filterInputs) {
      if (e.target.filterInput) {
        continue;
      }

      if (filterInput.value != e.target.value) {
        filterInput.value = e.target.value;
      }
    }
  }

  function doFilter(e) {
    let target = e.target;
    if (e.target == document) {
      // some browsers keep input data when refreshing a page
      // just pick one for initialization
      target = filterInputLeft;
    }

    // cache things for later
    let filterString = target.value.toLowerCase();
    let test_row_ths = document.querySelectorAll("tr.test th");

    // Loop through all list items, and hide those who don't match the search query
    for(th of test_row_ths) {
      let txtValue = th.textContent || th.innerText;
      if (txtValue.toLowerCase().indexOf(filterString) > -1) {
        th.parentElement.classList.remove('d-none');
      } else {
        th.parentElement.classList.add('d-none');
      }
    }
  }

  filterInputLeft.addEventListener('input', syncFilter);
  filterInputRight.addEventListener('input', syncFilter);

  window.addEventListener('load', doFilter);
  filterInputLeft.addEventListener('input', doFilter);
  filterInputRight.addEventListener('input', doFilter);

})();
(function() {

  function doToggleUnsupportedTests(e) {
    let test_row_trs = document.querySelectorAll("tr.test.test-unsupported");

    for (tr of test_row_trs) {
      tr.classList.toggle('d-none');
    }
  }

  let toggleUnsupportedTestsButton = document.getElementById("toggleUnsupportedTestsButton");
  toggleUnsupportedTestsButton.addEventListener('click', doToggleUnsupportedTests);

})();
