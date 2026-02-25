/**
 * ECharts Hook for Institutional Treasury Dashboard
 * 
 * Responsibilities:
 * 1. Loads ECharts from CDN if not already present.
 * 2. Initializes professional dark-themed candlestick/line chart.
 * 3. Handles real-time 'new-tick' events for smooth streaming.
 */

const EChartsHook = {
  mounted() {
    this.chart = null;
    this.pair = this.el.dataset.pair;
    this.initialData = JSON.parse(this.el.dataset.initial || "[]");

    this.ensureECharts(() => {
      this.initChart();
      
      // Listen for real-time ticks from the server
      this.handleEvent("new-tick", ({pair, price, time}) => {
        if (pair === this.pair) {
          this.appendTick(time, price);
        }
      });
    });

    // Handle window resize
    this.resizeHandler = () => this.chart && this.chart.resize();
    window.addEventListener("resize", this.resizeHandler);
  },

  destroyed() {
    window.removeEventListener("resize", this.resizeHandler);
    if (this.chart) this.chart.dispose();
  },

  initChart() {
    this.chart = window.echarts.init(this.el, 'dark');
    
    // Transform OHLC data: open, close, low, high
    const data = this.initialData.map(item => [item[1], item[2], item[3], item[4]]);
    const dates = this.initialData.map(item => new Date(item[0]).toLocaleTimeString());

    const option = {
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'cross' },
        backgroundColor: 'rgba(15, 23, 42, 0.9)',
        borderColor: '#334155',
        textStyle: { color: '#f1f5f9' }
      },
      grid: {
        left: '5%',
        right: '5%',
        bottom: '15%',
        top: '10%',
        containLabel: true
      },
      xAxis: {
        type: 'category',
        data: dates,
        scale: true,
        boundaryGap: false,
        axisLine: { lineStyle: { color: '#334155' } },
        splitLine: { show: false }
      },
      yAxis: {
        scale: true,
        axisLine: { lineStyle: { color: '#334155' } },
        splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.05)' } }
      },
      dataZoom: [
        { type: 'inside', start: 50, end: 100 },
        { show: false, type: 'slider', top: '90%', start: 50, end: 100 }
      ],
      series: [
        {
          name: this.pair,
          type: 'candlestick',
          data: data,
          itemStyle: {
            color: '#10b981',      // Emerald-500
            color0: '#f43f5e',     // Rose-500
            borderColor: '#10b981',
            borderColor0: '#f43f5e'
          },
          emphasis: {
            itemStyle: {
              borderWidth: 2
            }
          }
        },
        {
          name: 'MA5',
          type: 'line',
          data: this.calculateMA(5, data),
          smooth: true,
          showSymbol: false,
          lineStyle: { opacity: 0.5, width: 1, color: '#6366f1' }
        }
      ]
    };

    this.chart.setOption(option);
  },

  appendTick(time, price) {
    if (!this.chart) return;

    const formattedTime = new Date(time).toLocaleTimeString();
    const currentOption = this.chart.getOption();
    
    // Simple update logic: for this demo, we append a new candle
    // In a prod env, we'd update the last candle if within the same bucket
    const dates = currentOption.xAxis[0].data;
    const seriesData = currentOption.series[0].data;

    dates.push(formattedTime);
    seriesData.push([price, price, price, price]); // Open, Close, Low, High all the same for a single tick

    // Keep the chart performant by limiting records
    if (dates.length > 100) {
      dates.shift();
      seriesData.shift();
    }

    this.chart.setOption({
      xAxis: { data: dates },
      series: [
        { data: seriesData },
        { data: this.calculateMA(5, seriesData) }
      ]
    });
  },

  calculateMA(dayCount, data) {
    var result = [];
    for (var i = 0, len = data.length; i < len; i++) {
        if (i < dayCount) {
            result.push('-');
            continue;
        }
        var sum = 0;
        for (var j = 0; j < dayCount; j++) {
            sum += parseFloat(data[i - j][1]); // Using 'close' price
        }
        result.push((sum / dayCount).toFixed(4));
    }
    return result;
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
  },

  updated() {
    const newData = JSON.parse(this.el.dataset.initial || "[]");
    // Only re-init if we have new data and the chart wasn't fully initialized or was empty
    if (newData.length > 0 && (!this.chart || this.initialData.length === 0)) {
      this.initialData = newData;
      this.ensureECharts(() => {
        if (this.chart) this.chart.dispose();
        this.initChart();
      });
    }
  }
};

export default EChartsHook;
