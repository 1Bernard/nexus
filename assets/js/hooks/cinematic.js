export const CursorFollower = {
  mounted() {
    this.ring = this.el.querySelector('#cursor-ring');
    this.dot = this.el.querySelector('#cursor-dot');
    
    // Low latency direct tracking
    window.addEventListener('mousemove', (e) => {
      const x = e.clientX;
      const y = e.clientY;
      
      this.dot.style.transform = `translate(${x}px, ${y}px)`;
      this.ring.style.transform = `translate(${x}px, ${y}px)`;
    });

    // Hover effects for the 'Museum Scan' feel
    document.querySelectorAll('.interactive').forEach(el => {
      el.addEventListener('mouseenter', () => {
        this.ring.classList.add('scale-[3]', 'border-cyan-500', 'bg-cyan-500/5');
        this.dot.classList.add('scale-[2]', 'bg-cyan-400');
        
        // Custom reveal logic if needed
        if (el.dataset.scan) {
           el.classList.add('scanned');
        }
      });
      el.addEventListener('mouseleave', () => {
        this.ring.classList.remove('scale-[3]', 'border-cyan-500', 'bg-cyan-500/5');
        this.dot.classList.remove('scale-[2]', 'bg-cyan-400');
      });
    });
  }
};

export const CubeController = {
  mounted() {
    this.cube = this.el.querySelector('.exhibit-cube');
    
    window.addEventListener('mousemove', (e) => {
      const rect = this.el.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;
      
      const rotateX = -y / 5;
      const rotateY = x / 5;
      
      this.cube.style.transform = `rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
    });
  }
};

export const ScrollReveal = {
  mounted() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('active');
        } else {
          entry.target.classList.remove('active');
        }
      });
    }, {
      threshold: 0.1,
      rootMargin: "0px 0px -10% 0px"
    });

    this.el.querySelectorAll('.reveal-text').forEach(el => observer.observe(el));
  }
};
