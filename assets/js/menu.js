document.addEventListener('readystatechange', (_doc, _e) => {
  button = document.querySelector('.hs-collapse-toggle')
  navbar = document.querySelector('#navbar-collapse-with-animation')

  button.addEventListener('click', (_b, _e) => {
    hidden = button.querySelector('svg.hidden')
    shown = button.querySelector('svg:not(.hidden)')
    hidden.classList.remove('hidden')
    shown.classList.add('hidden')
    if (navbar.classList.contains('hidden')) {
      navbar.classList.remove('hidden')
    } else {
      navbar.classList.add('hidden')
    }
  })
})
