const ForecastChart = {
  mounted() {
    this.chart = null;
    this.ensureECharts(() => {
      this.initChart();
    });

    window.addEventListener("resize", () => {
      if (this.chart) this.chart.resize();
    });
  },

  destroyed() {
    if (this.chart) this.chart.dispose();
  },

  updated() {
    if (this.chart) {
      const data = JSON.parse(this.el.dataset.points || "[]");
      this.updateChart(data);
    }
  },

  initChart() {
    this.chart = window.echarts.init(this.el, 'dark');
    const data = JSON.parse(this.el.dataset.points || "[]");
    this.updateChart(data);
  },

  updateChart(data) {
    if (!this.chart || data.length === 0) return;

    const dates = data.map(d => d.date);
    const predictions = data.map(d => parseFloat(d.predicted_amount) || 0.0);

    const option = {
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'axis',
        backgroundColor: 'rgba(15, 23, 42, 0.9)',
        borderColor: '#334155',
        textStyle: { color: '#f1f5f9' },
        formatter: (params) => {
          const p = params[0];
          return `<div class="p-1">
            <div class="text-[10px] text-slate-500 uppercase font-bold">${p.name}</div>
            <div class="text-sm font-bold mt-0.5">€${parseFloat(p.value).toLocaleString()}</div>
          </div>`;
        }
      },
      grid: {
        left: '2%',
        right: '2%',
        bottom: '5%',
        top: '10%',
        containLabel: true
      },
      xAxis: {
        type: 'category',
        data: dates,
        axisLine: { lineStyle: { color: '#31394a' } },
        axisLabel: { color: '#64748b', fontSize: 10 },
        splitLine: { show: false }
      },
      yAxis: {
        type: 'value',
        axisLine: { show: false },
        axisLabel: { color: '#64748b', fontSize: 10 },
        splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.03)' } }
      },
      series: [
        {
          data: predictions,
          type: 'line',
          smooth: true,
          symbol: 'circle',
          symbolSize: 6,
          itemStyle: { color: '#6366f1' },
          lineStyle: { width: 3, color: '#6366f1' },
          areaStyle: {
            color: new window.echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(99, 102, 241, 0.2)' },
              { offset: 1, color: 'rgba(99, 102, 241, 0)' }
            ])
          },
          animationDuration: 1500,
          animationEasing: 'cubicOut'
        }
      ]
    };

    this.chart.setOption(option);
  },

  ensureECharts(callback) {
    if (window.echarts) {
      callback();
    } else {
      const script = document.createElement("script");
      script.src = "https://cdn.jsdelivr.net/npm/echarts@5.5.0/dist/echarts.min.js";
      script.onload = callback;
      document.head.appendChild(script);
    }
  }
};

export default ForecastChart;
